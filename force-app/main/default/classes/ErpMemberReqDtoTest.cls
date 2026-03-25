@IsTest
private class ErpMemberReqDtoTest {
  @IsTest
  static void updateGradeRequest_constructor_initializesList() {
    ErpMemberReqDto.UpdateGradeRequest req = new ErpMemberReqDto.UpdateGradeRequest();

    System.assertNotEquals(null, req);
    System.assertNotEquals(null, req.memebrModelList);
    System.assertEquals(0, req.memebrModelList.size());

    req.ID_UPDATE = 'TEST-USER';
    req.memebrModelList.add(new ErpMemberReqDto.UpdateGradeMemebrModel('00001', '01'));

    System.assertEquals('TEST-USER', req.ID_UPDATE);
    System.assertEquals(1, req.memebrModelList.size());
    System.assertEquals('00001', req.memebrModelList[0].NO_MBR);
    System.assertEquals('01', req.memebrModelList[0].CD_GRADE_MBR);
  }

  @IsTest
  static void updateGradeMemberModel_constructors_mapFields() {
    ErpMemberReqDto.UpdateGradeMemebrModel emptyModel = new ErpMemberReqDto.UpdateGradeMemebrModel();
    System.assertEquals(null, emptyModel.NO_MBR);
    System.assertEquals(null, emptyModel.CD_GRADE_MBR);

    ErpMemberReqDto.UpdateGradeMemebrModel filledModel = new ErpMemberReqDto.UpdateGradeMemebrModel('00002', '02');
    System.assertEquals('00002', filledModel.NO_MBR);
    System.assertEquals('02', filledModel.CD_GRADE_MBR);
  }

  @IsTest
  static void updateMagazineSubscriptionRequest_constructor_initializesList() {
    ErpMemberReqDto.UpdateMagazineSubscriptionRequest req = new ErpMemberReqDto.UpdateMagazineSubscriptionRequest();

    System.assertNotEquals(null, req);
    System.assertNotEquals(null, req.memebrModelList);
    System.assertEquals(0, req.memebrModelList.size());

    req.ID_UPDATE = 'TEST-USER';
    req.memebrModelList.add(new ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel('00003', 'Y', '20260301', 'UNKNOWN'));

    System.assertEquals('TEST-USER', req.ID_UPDATE);
    System.assertEquals(1, req.memebrModelList.size());
    System.assertEquals('00003', req.memebrModelList[0].NO_MBR);
    System.assertEquals('Y', req.memebrModelList[0].YM_RECEIVE_MAGAZINE);
    System.assertEquals('20260301', req.memebrModelList[0].DT_RECEIVE_MAGAZINE);
    System.assertEquals(null, req.memebrModelList[0].CD_TYPE_MAGAZINE_SEASON);
  }

  @IsTest
  static void updateMagazineSubscriptionMemberModel_defaultConstructor_keepsFieldsNull() {
    ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel model = new ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel();

    System.assertEquals(null, model.NO_MBR);
    System.assertEquals(null, model.YM_RECEIVE_MAGAZINE);
    System.assertEquals(null, model.DT_RECEIVE_MAGAZINE);
    System.assertEquals(null, model.CD_TYPE_MAGAZINE_SEASON);
  }

  @IsTest
  static void updateMagazineSubscriptionMemberModel_invalidSeason_mapsToNull() {
    ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel model = new ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel(
      '00004',
      'N',
      '20260401',
      'INVALID'
    );

    System.assertEquals('00004', model.NO_MBR);
    System.assertEquals('N', model.YM_RECEIVE_MAGAZINE);
    System.assertEquals('20260401', model.DT_RECEIVE_MAGAZINE);
    System.assertEquals(null, model.CD_TYPE_MAGAZINE_SEASON);
  }

  @IsTest
  static void updateMagazineSubscriptionMemberModel_blankSeason_mapsToNull() {
    ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel model = new ErpMemberReqDto.UpdateMagazineSubscriptionMemebrModel(
      '00005',
      'Y',
      '20260501',
      null
    );

    System.assertEquals('00005', model.NO_MBR);
    System.assertEquals('Y', model.YM_RECEIVE_MAGAZINE);
    System.assertEquals('20260501', model.DT_RECEIVE_MAGAZINE);
    System.assertEquals(null, model.CD_TYPE_MAGAZINE_SEASON);
  }

  @IsTest
  static void updateMemberSmsReceiveRequest_fields_areAssignable() {
    ErpMemberReqDto.UpdateMemberSmsReceiveRequest req = new ErpMemberReqDto.UpdateMemberSmsReceiveRequest();

    req.P_NO_MBR = '00006';
    req.P_NM_MBR_KOR = 'Test User';
    req.P_CD_STORE_REGI = 'AD004';
    req.P_NO_CELLPHONE1 = '01012345678';
    req.P_YN_RECEIVE_SMS = 'N';
    req.P_ID_INSERT = 'TEST-USER';

    System.assertEquals('00006', req.P_NO_MBR);
    System.assertEquals('Test User', req.P_NM_MBR_KOR);
    System.assertEquals('AD004', req.P_CD_STORE_REGI);
    System.assertEquals('01012345678', req.P_NO_CELLPHONE1);
    System.assertEquals('N', req.P_YN_RECEIVE_SMS);
    System.assertEquals('TEST-USER', req.P_ID_INSERT);
  }
}