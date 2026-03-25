public with sharing class ErrorUtil {
  /**
   * DML Error 내용 저장
   */
  public static void createDmlError(List<Database.SaveResult> saveResults, List<SObject> objectList, String topic) {
    // try {
    //   //error object list
    //   List<Error_Log__c> errorList = new List<Error_Log__c>();
    //   for (integer i = 0; i < saveResults.size(); i++) {
    //     if (saveResults.get(i).isSuccess()) {
    //       //add the code here if you want to do something in success case
    //     } //error case
    //     else if (!saveResults.get(i).isSuccess()) {
    //       // Operation failed, so get all errors
    //       Database.Error dbError = saveResults.get(i).getErrors().get(0);

    //       system.debug('Failed record id: ' + (String) objectList[i].get('Id'));
    //       String recordId, recordName = '';
    //       if (objectList.size() > 0) {
    //         recordId = (String) objectList[i].get('Id');
    //         recordName = (String) objectList[i].get('Name');
    //       }

    //       Error_Log__c err = new Error_Log__c();
    //       err.Error_Message__c = dbError.getMessage();
    //       err.Stack_Trace__c = String.valueOf(dbError.getStatusCode());
    //       err.Record_ID__c = recordId;
    //       err.Record_Name__c = recordName;
    //       err.Topic__c = topic;
    //       //add error in the list
    //       errorList.add(err);
    //     }
    //   }
    //   if (errorList.size() > 0) {
    //     insert errorList;
    //   }
    // } catch (Exception e) {
    //   System.debug('Exception has occured! ' + e.getMessage());
    // }
  }

  /**
   * 일반 Error 내용 저장
   */
  public static void createError(String errorMessage, String line) {
    try {
      Error_Log__c err = new Error_Log__c();
      err.Error_Message__c = errorMessage;
      err.Line__c = line;

      insert err;
    } catch (Exception e) {
      System.debug('Exception has occured! ' + e.getMessage());
    }
  }

  /**
   * API Error 내용 저장
   */
  public static void createApiError(String apiEndpoint, String line, String errorMessage, Integer code) {
    try {
      Error_Log__c err = new Error_Log__c();
      err.ApiEndpoint__c = apiEndpoint;
      err.Line__c = line;
      err.Error_Message__c = errorMessage;
      err.Code__c = code;

      insert err;
    } catch (Exception e) {
      System.debug('Exception has occured! ' + e.getMessage());
    }
  }
}