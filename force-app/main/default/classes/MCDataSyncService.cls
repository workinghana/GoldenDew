public class MCDataSyncService {
  @TestVisible
  private static List<MC_Sync_Object__mdt> testConfigs;

  // Batch로 동기화 (대량 데이터용 - 건수 제한 없음)
  public static void syncObject(String metadataName) {
    Database.executeBatch(new MCDataSyncBatch(metadataName), 200);
  }

  // 활성 오브젝트 전체 동기화
  public static void syncAll() {
    List<MC_Sync_Object__mdt> configs = testConfigs;
    if (configs == null) {
      configs = [
        SELECT DeveloperName
        FROM MC_Sync_Object__mdt
        WHERE Is_Active__c = TRUE
      ];
    }

    for (MC_Sync_Object__mdt config : configs) {
      Database.executeBatch(new MCDataSyncBatch(config.DeveloperName), 200);
    }
  }
}