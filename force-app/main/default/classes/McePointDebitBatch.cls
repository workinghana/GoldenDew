/**
 * MCE 포인트(적립/차감) 이벤트 전송 배치
 * - start()에서 TransactionJournal + (Order -> Account)까지 함께 조회하여 execute()에서 TJ 재조회 제거
 * - execute()에서는 SOQL 2회만 수행:
 *   1) LoyaltyLedger (TJ Id IN)
 *   2) LoyaltyMemberCurrency (MemberId IN)
 * - 멤버별 1회 callout
 *
 * 실행:
 *   Database.executeBatch(new McePointDebitBatch(tjIds), 50);
 */
public with sharing class McePointDebitBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private static final String POINT_CURRENCY_NAME = '포인트';

    private Set<String> totalSuccess = new Set<String>(); // memberId(String)
    private Set<String> totalFail = new Set<String>(); // memberId(String)

    private Set<Id> ids;

    public McePointDebitBatch(Set<Id> ids) {
        this.ids = (ids == null) ? new Set<Id>() : ids;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (ids.isEmpty()) {
            return Database.getQueryLocator(
                [
                    SELECT Id
                    FROM TransactionJournal
                    WHERE Id = NULL
                ]
            );
        }

        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    JournalDate,
                    OrderId,
                    Order.EffectiveDate,
                    Order.AccountId,
                    Order.Account.Name,
                    Order.Account.StoreCode__c,
                    ActivityDate
                FROM TransactionJournal
                WHERE Id IN :ids
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        String jobId = (bc == null) ? null : bc.getJobId();
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, jobId, null);
        logger.logging(McePointDebitBatch.class.getName());
        logger.setRequestDatetime(Datetime.now());

        Set<String> successIds = new Set<String>();
        Set<String> failIds = new Set<String>();
        List<String> failMsgs = new List<String>();

        try {
            if (scope == null || scope.isEmpty()) {
                logger.setStatus('SUCCESS');
                logger.setDescription('scope is empty');
                return;
            }

            // scope = TransactionJournal
            List<TransactionJournal> tjList = (List<TransactionJournal>) scope;

            // (선택) logger scoped ids
            try {
                logger.setScopedIds(scope, 'Id');
            } catch (Exception ignore) {
            }

            // 1) TJ Id 수집 + TJ 기반 StoreInfo Map 구성(추가 SOQL 없음)
            Set<Id> tjIdSet = new Set<Id>();
            Map<Id, StoreInfo> storeInfoByTjId = new Map<Id, StoreInfo>();

            for (TransactionJournal tj : tjList) {
                tjIdSet.add(tj.Id);

                StoreInfo si = new StoreInfo();
                si.storeCode = (tj.OrderId != null &&
                    tj.Order.Account != null)
                    ? tj.Order.Account.StoreCode__c
                    : null;

                si.storeName = (tj.OrderId != null &&
                    tj.Order.Account != null)
                    ? tj.Order.Account.Name
                    : null;

                si.purchaseDate = TimeUtil.toKstIsoZ(tj.ActivityDate);

                storeInfoByTjId.put(tj.Id, si);
            }

            // 2) TJ -> LoyaltyLedger 조회 (SOQL 1회)
            //    - payload에 필요한 Contact 관계까지 포함
            List<LoyaltyLedger> llList = [
                SELECT
                    Id,
                    TransactionJournalId,
                    LoyaltyProgramMemberId,
                    EventType,
                    Points,
                    LoyaltyProgramCurrency.Name,
                    LoyaltyProgramMember.Contact.MemberNo__c,
                    LoyaltyProgramMember.Contact.Phone,
                    LoyaltyProgramMember.Contact.Email,
                    LoyaltyProgramMember.Contact.LastName,
                    LoyaltyProgramMember.Contact.Grade__c
                FROM LoyaltyLedger
                WHERE
                    TransactionJournalId IN :tjIdSet
                    AND LoyaltyProgramCurrency.Name = :POINT_CURRENCY_NAME
            ];

            if (llList.isEmpty()) {
                logger.setStatus('SUCCESS');
                logger.setDescription('No LoyaltyLedger found. tjCnt=' + tjIdSet.size());
                return;
            }

            // 3) 멤버별 집계 + memberIdSet 수집
            Map<Id, MemberAgg> aggByMemberId = new Map<Id, MemberAgg>();
            Set<Id> memberIdSet = new Set<Id>();

            for (LoyaltyLedger ll : llList) {
                Id memberId = ll.LoyaltyProgramMemberId;
                if (memberId == null) {
                    continue;
                }

                memberIdSet.add(memberId);

                if (!aggByMemberId.containsKey(memberId)) {
                    aggByMemberId.put(memberId, new MemberAgg(memberId));
                }

                String direction = deriveDirection(ll); // CREDIT / DEBIT (2가지 케이스)
                aggByMemberId.get(memberId).add(direction, ll.Points, ll.TransactionJournalId);

                // 대표 ledger(연락처/등급 등) 보관
                if (aggByMemberId.get(memberId).sampleLedger == null) {
                    aggByMemberId.get(memberId).sampleLedger = ll;
                }

                // 대표 TJ(StoreInfo) 보관: 첫 TJ를 멤버 대표로 사용
                if (
                    aggByMemberId.get(memberId).sampleTjId == null &&
                    ll.TransactionJournalId != null
                ) {
                    aggByMemberId.get(memberId).sampleTjId = ll.TransactionJournalId;
                }
            }

            if (memberIdSet.isEmpty()) {
                logger.setStatus('SUCCESS');
                logger.setDescription('No member target. ledgerCnt=' + llList.size());
                return;
            }

            // 4) 잔여 포인트(LoyaltyMemberCurrency.PointsBalance) 조회 (SOQL 1회)
            Map<Id, Decimal> balanceByMemberId = new Map<Id, Decimal>();
            for (LoyaltyMemberCurrency lmc : [
                SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
                FROM LoyaltyMemberCurrency
                WHERE
                    LoyaltyMemberId IN :memberIdSet
                    AND LoyaltyProgramCurrency.Name = :POINT_CURRENCY_NAME
            ]) {
                balanceByMemberId.put(lmc.LoyaltyMemberId, lmc.PointsBalance);
            }

            // 5) 멤버별 callout (멤버당 1회)
            Integer apiSuccessCnt = 0;
            Integer apiFailCnt = 0;

            for (Id memberId : aggByMemberId.keySet()) {
                // 트랜잭션당 callout 100 제한 방어
                if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                    failIds.add((String) memberId);
                    failMsgs.add('Callout limit reached in this execute. memberId=' + memberId);
                    continue;
                }

                MemberAgg agg = aggByMemberId.get(memberId);
                LoyaltyLedger base = agg.sampleLedger;

                String memberNo = (base != null &&
                    base.LoyaltyProgramMember != null &&
                    base.LoyaltyProgramMember.Contact != null)
                    ? base.LoyaltyProgramMember.Contact.MemberNo__c
                    : null;

                if (String.isBlank(memberNo)) {
                    failIds.add((String) memberId);
                    failMsgs.add('MemberNo__c is blank. memberId=' + memberId);
                    continue;
                }

                Decimal available = balanceByMemberId.containsKey(memberId)
                    ? balanceByMemberId.get(memberId)
                    : 0;
                if (available == null) {
                    available = 0;
                }

                StoreInfo si = (agg.sampleTjId != null)
                    ? storeInfoByTjId.get(agg.sampleTjId)
                    : null;

                try {
                    String pk = MceEventReqDto.buildPk(memberNo);

                    Map<String, Object> data = new Map<String, Object>{
                        'ContactKey' => memberNo,
                        'PK' => pk,
                        'SubscriberKey' => memberNo,
                        'Phone' => base.LoyaltyProgramMember.Contact.Phone,
                        'EmailAddress' => base.LoyaltyProgramMember.Contact.Email,
                        'LastName' => base.LoyaltyProgramMember.Contact.LastName,
                        'AvailablePoints' => available,
                        'UsedPoints' => agg.debitTotal, // 차감 합계(양수)
                        // 'CreditPoints' => agg.creditTotal, // 적립 합계(양수)
                        'Grade__c' => base.LoyaltyProgramMember.Contact.Grade__c,
                        'StoreCode__c' => (si == null ? null : si.storeCode),
                        'Purchase_Store' => (si == null ? null : si.storeName),
                        'PurchaseDate' => (si == null
                            ? null
                            : (si.purchaseDate == null ? null : String.valueOf(si.purchaseDate)))
                    };

                    DebugUtil.pretty('data', data);

                    MceEventReqDto req = new MceEventReqDto(data).setContactKey(pk);
                    DebugUtil.pretty('req', req);

                    // ✅ 실제 callout
                    //   MceApiClient.sendInteractionEvent(req);

                    apiSuccessCnt++;
                    successIds.add((String) memberId);
                } catch (Exception ex) {
                    apiFailCnt++;
                    failIds.add((String) memberId);
                    failMsgs.add(
                        'MCE callout failed. memberId=' + memberId + ', msg=' + ex.getMessage()
                    );
                }
            }

            failIds.removeAll(successIds);

            Boolean hasAnyFail = !failIds.isEmpty();
            Boolean hasAnySuccess = !successIds.isEmpty();

            if (hasAnyFail && hasAnySuccess) {
                logger.setStatus('PARTIAL');
            } else if (hasAnyFail) {
                logger.setStatus('ERROR');
            } else {
                logger.setStatus('SUCCESS');
            }

            logger.setDescription(
                'chunkSize=' +
                    scope.size() +
                    ', tjCnt=' +
                    tjIdSet.size() +
                    ', ledgerCnt=' +
                    llList.size() +
                    ', memberCnt=' +
                    memberIdSet.size() +
                    ', lmcCnt=' +
                    balanceByMemberId.size() +
                    ', apiSuccess=' +
                    apiSuccessCnt +
                    ', apiFail=' +
                    apiFailCnt
            );
        } catch (Exception e) {
            logger.createExceptionLog(e);
            logger.setStatus('ERROR');
            failMsgs.add('Unhandled exception: ' + e.getMessage());
        } finally {
            totalSuccess.addAll(successIds);
            totalFail.addAll(failIds);

            if (!successIds.isEmpty()) {
                logger.setSuccessRecordIds(successIds);
            }
            if (!failIds.isEmpty()) {
                logger.setFailedRecordIds(failIds);
            }
            if (!failMsgs.isEmpty()) {
                logger.setErrorMessage(String.join(failMsgs, ' | '));
            }

            logger.setResponseDatetime(Datetime.now());
            logger.addLog();
            ApexLogger.insertLogs();
        }
    }

    public void finish(Database.BatchableContext bc) {
        totalFail.removeAll(totalSuccess);

        Integer successCnt = totalSuccess.size();
        Integer failCnt = totalFail.size();

        String status;
        SchedulerNotificationPublisher.ResultStatus notifStatus;

        if (failCnt > 0 && successCnt > 0) {
            status = 'PARTIAL';
            notifStatus = SchedulerNotificationPublisher.ResultStatus.PARTIAL;
        } else if (failCnt > 0) {
            status = 'ERROR';
            notifStatus = SchedulerNotificationPublisher.ResultStatus.ERROR;
        } else {
            status = 'SUCCESS';
            notifStatus = SchedulerNotificationPublisher.ResultStatus.SUCCESS;
        }

        ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
        logger.logging(McePointDebitBatch.class.getName());
        logger.setStatus(status);
        logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
        logger.setResponseDatetime(Datetime.now());
        logger.addLog();
        ApexLogger.insertLogs();

        String msg =
            'Status=' +
            status +
            ', success=' +
            successCnt +
            ', fail=' +
            failCnt +
            ', jobId=' +
            bc.getJobId();
        SchedulerNotificationPublisher.publishResult(
            'McePointDebitBatch',
            notifStatus,
            msg,
            bc.getJobId(),
            null
        );
    }

    // -------------------------
    // CREDIT/DEBIT 판별: 두 가지 케이스만 처리
    // - EventType 우선('Credit'/'Debit')
    // - fallback: Points 부호
    // -------------------------
    private static String deriveDirection(LoyaltyLedger ll) {
        if (ll == null) {
            return 'CREDIT';
        }

        if (!String.isBlank(ll.EventType)) {
            if (ll.EventType == 'Credit') {
                return 'CREDIT';
            }
            if (ll.EventType == 'Debit') {
                return 'DEBIT';
            }
        }

        Decimal p = ll.Points;
        return (p != null && p < 0) ? 'DEBIT' : 'CREDIT';
    }

    @TestVisible
    private static String deriveDirectionForTest(String eventType, Decimal points) {
        LoyaltyLedger ll = new LoyaltyLedger();
        ll.EventType = eventType;
        ll.Points = points;
        return deriveDirection(ll);
    }

    @TestVisible
    private static void executeForTest(List<TransactionJournal> tjs) {
        List<SObject> scope = new List<SObject>();
        if (tjs != null) {
            scope.addAll(tjs);
        }
        new McePointDebitBatch(new Set<Id>()).execute(null, scope);
    }

    // =========================
    // 멤버 단위 집계
    // =========================
    public class MemberAgg {
        public Id memberId;
        public Decimal creditTotal = 0;
        public Decimal debitTotal = 0;

        public LoyaltyLedger sampleLedger; // 연락처/등급 등 공통값
        public Id sampleTjId; // StoreInfo 매핑용 대표 TJ

        public MemberAgg(Id memberId) {
            this.memberId = memberId;
        }

        public void add(String direction, Decimal points, Id tjId) {
            if (points == null) {
                points = 0;
            }
            Decimal v = points.abs();

            if (direction == 'DEBIT') {
                debitTotal += v;
            } else {
                creditTotal += v;
            }

            if (this.sampleTjId == null && tjId != null) {
                this.sampleTjId = tjId;
            }
        }
    }

    // =========================
    // TJ 기준 Store/Purchase 정보
    // =========================
    public class StoreInfo {
        public String storeCode;
        public String storeName;
        public String purchaseDate;
    }
}