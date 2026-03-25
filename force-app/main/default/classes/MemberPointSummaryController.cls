global with sharing class MemberPointSummaryController {
    global class MemberPointSummaryDTO {
        global String pointSubtypeId; // 하위 유형 Id (Lookup일 경우)
        global String pointSubtypeName; // 하위 유형 이름 (레이블)
        global Decimal totalAccrued; // 적립 포인트 합계
        global Decimal totalRedeemed; // 사용 포인트 합계
        global Decimal totalExpired; // 소멸 포인트 합계
    }

    @RemoteAction
    @ReadOnly
    global static List<MemberPointSummaryDTO> getMemberPointSummary(Id memberId) {
        if (memberId == null) {
            throw new AuraHandledException('memberId is required.');
        }

        List<AggregateResult> aggList = [
            SELECT
                CurrencySubTypeName__c pointSubtypeName,
                SUM(AccruedPoints__c) totalAccrued,
                SUM(RedeemedPoints__c) totalRedeemed,
                SUM(ExpiredPoints__c) totalExpired
            FROM LoyaltyAggrSubPointExprLedger__c
            WHERE LoyaltyProgramMemberId__c = :memberId
            GROUP BY CurrencySubTypeName__c
        ];

        List<MemberPointSummaryDTO> result = new List<MemberPointSummaryDTO>();

        for (AggregateResult ar : aggList) {
            result.add(
                toSummaryDto(
                    (String) ar.get('pointSubtypeName'),
                    (Decimal) ar.get('totalAccrued'),
                    (Decimal) ar.get('totalRedeemed'),
                    (Decimal) ar.get('totalExpired')
                )
            );
        }

        return result;
    }

    @TestVisible
    private static MemberPointSummaryDTO toSummaryDto(
        String pointSubtypeName,
        Decimal totalAccrued,
        Decimal totalRedeemed,
        Decimal totalExpired
    ) {
        MemberPointSummaryDTO dto = new MemberPointSummaryDTO();
        dto.pointSubtypeName = pointSubtypeName;
        dto.totalAccrued = totalAccrued == null ? 0 : totalAccrued;
        dto.totalRedeemed = totalRedeemed == null ? 0 : totalRedeemed;
        dto.totalExpired = totalExpired == null ? 0 : totalExpired;
        return dto;
    }
}