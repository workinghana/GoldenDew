/**
 * 설정-쿠폰 (VoucherDefinition)의 쿠폰 관리 번호 필드에 값 주입 Service
 * @author ChangHwan Kim
 * @since 2026-03-24
 */
public with sharing class CouponSequenceService {
  private static final String PREFIX = 'COP';

  public static void assignCouponCodes(List<VoucherDefinition> newList) {
    System.debug('assignCouponCodes 진입');
    if (newList == null || newList.isEmpty()) {
      return;
    }

    // 이미 값이 있는 건 제외
    List<VoucherDefinition> targetList = new List<VoucherDefinition>();
    for (VoucherDefinition rec : newList) {
      if (String.isBlank(rec.CouponManNo__c)) {
        targetList.add(rec);
      }
    }

    if (targetList.isEmpty()) {
      return;
    }

    // Key별 그룹핑
    Map<String, List<VoucherDefinition>> recordsByKey = new Map<String, List<VoucherDefinition>>();
    Set<String> keySet = new Set<String>();

    for (VoucherDefinition rec : targetList) {
      Date baseDate = Date.today();
      String yearStr = String.valueOf(baseDate.year());
      String monthCode = getMonthCode(baseDate.month());

      String key = PREFIX + '-' + yearStr + '-' + monthCode;
      keySet.add(key);

      if (!recordsByKey.containsKey(key)) {
        recordsByKey.put(key, new List<VoucherDefinition>());
      }
      recordsByKey.get(key).add(rec);
    }

    // 기존 시퀀스 조회 + 잠금
    Map<String, SequenceControl__c> seqMap = new Map<String, SequenceControl__c>();
    if (!keySet.isEmpty()) {
      for (SequenceControl__c seq : [
        SELECT Id, Key__c, LastSeq__c
        FROM SequenceControl__c
        WHERE Key__c IN :keySet
        FOR UPDATE
      ]) {
        seqMap.put(seq.Key__c, seq);
      }
    }

    // 없는 Key는 생성
    List<SequenceControl__c> toInsert = new List<SequenceControl__c>();
    for (String key : keySet) {
      if (!seqMap.containsKey(key)) {
        SequenceControl__c newSeq = new SequenceControl__c();
        newSeq.Key__c = key;
        newSeq.LastSeq__c = 0;
        toInsert.add(newSeq);
      }
    }

    if (!toInsert.isEmpty()) {
      try {
        insert toInsert;
      } catch (DmlException e) {
        // 동시 생성 충돌 가능성 대비: 다시 조회
      }

      for (SequenceControl__c seq : [
        SELECT Id, Key__c, LastSeq__c
        FROM SequenceControl__c
        WHERE Key__c IN :keySet
        FOR UPDATE
      ]) {
        seqMap.put(seq.Key__c, seq);
      }
    }

    // 번호 발급
    List<SequenceControl__c> toUpdate = new List<SequenceControl__c>();

    for (String key : recordsByKey.keySet()) {
      SequenceControl__c seq = seqMap.get(key);
      Integer currentSeq = (seq.LastSeq__c == null) ? 0 : Integer.valueOf(seq.LastSeq__c);

      for (VoucherDefinition rec : recordsByKey.get(key)) {
        Date baseDate = Date.today();
        String yearStr = String.valueOf(baseDate.year());
        String monthCode = getMonthCode(baseDate.month());

        currentSeq++;
        rec.CouponManNo__c = PREFIX + yearStr + monthCode + pad4(currentSeq);
      }

      seq.LastSeq__c = currentSeq;
      toUpdate.add(seq);
    }

    if (!toUpdate.isEmpty()) {
      System.debug('if (!toUpdate.isEmpty()) { 진입');

      update toUpdate;
    }
  }

  private static String getMonthCode(Integer month) {
    Map<Integer, String> monthMap = new Map<Integer, String>{
      1 => 'JA',
      2 => 'FE',
      3 => 'MA',
      4 => 'AP',
      5 => 'MY',
      6 => 'JN',
      7 => 'JL',
      8 => 'AU',
      9 => 'SE',
      10 => 'OC',
      11 => 'NO',
      12 => 'DE'
    };

    if (!monthMap.containsKey(month)) {
      throw new AuraHandledException('유효하지 않은 월입니다. month=' + month);
    }

    return monthMap.get(month);
  }

  private static String pad4(Integer seq) {
    return String.valueOf(seq).leftPad(4, '0');
  }
}