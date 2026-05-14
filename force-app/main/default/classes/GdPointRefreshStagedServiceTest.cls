@IsTest
private class GdPointRefreshStagedServiceTest {
  @IsTest
  static void cleanup_removesStageRowsAndMarksRun() {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = 'TEST-STAGE';
    run.MemberId__c = '0lM000000000001AAA';
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.Status__c = 'Staged';
    run.CurrentStep__c = 'SOURCE_COLLECTED';
    insert run;

    insert new List<GdPointRefreshStage__c>{
      new GdPointRefreshStage__c(
        Run__c = run.Id,
        StageType__c = 'EVENT',
        EventDate__c = Date.newInstance(2026, 5, 18),
        Sequence__c = 1,
        EventType__c = GdPointRefreshEngine.EVENT_CREDIT,
        EventKey__c = 'E1',
        SourceKey__c = 'E1',
        SaleNo__c = '-',
        OriginKey__c = 'E1',
        PointTypeCode__c = '04',
        Points__c = 100,
        RemainingPoints__c = 100,
        ExpiryDate__c = Date.newInstance(2028, 5, 18),
        SortKey__c = '20260518:0000000001:E1',
        TargetJournalId__c = '-',
        TargetLedgerId__c = '-'
      ),
      new GdPointRefreshStage__c(
        Run__c = run.Id,
        StageType__c = 'EVENT',
        EventDate__c = Date.newInstance(2026, 5, 18),
        Sequence__c = 2,
        EventType__c = GdPointRefreshEngine.EVENT_CREDIT,
        EventKey__c = 'E2',
        SourceKey__c = 'E2',
        SaleNo__c = '-',
        OriginKey__c = 'E2',
        PointTypeCode__c = '04',
        Points__c = 200,
        RemainingPoints__c = 200,
        ExpiryDate__c = Date.newInstance(2028, 5, 18),
        SortKey__c = '20260518:0000000002:E2',
        TargetJournalId__c = '-',
        TargetLedgerId__c = '-'
      )
    };

    Test.startTest();
    Id jobId = GdPointRefreshStagedService.cleanup(run.Id);
    Test.stopTest();

    System.assertNotEquals(null, jobId);
    System.assertEquals(0, [SELECT COUNT() FROM GdPointRefreshStage__c WHERE Run__c = :run.Id]);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Cleaned', refreshedRun.Status__c);
    System.assert(refreshedRun.CurrentStep__c.startsWith('CLEANED_STAGE_ROWS_'));
  }
}