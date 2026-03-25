@IsTest
private class ErpPointReqDtoTest {

  /* =====================================================
   * Op enum 값 커버
   * ===================================================== */
  @IsTest
  static void test_op_enum_value() {
    ErpPointReqDto.Op op = ErpPointReqDto.Op.EXPIRY_OP;
    System.assertEquals(ErpPointReqDto.Op.EXPIRY_OP, op, 'EXPIRY_OP enum 값');
    System.assertEquals(ErpPointReqDto.Op.EXPIRY_OP, ErpPointReqDto.Op.valueOf('EXPIRY_OP'));
  }

  /* =====================================================
   * ErpPointReqDto op 필드 할당
   * ===================================================== */
  @IsTest
  static void test_dto_opField_assignment() {
    ErpPointReqDto dto = new ErpPointReqDto();
    dto.op = ErpPointReqDto.Op.EXPIRY_OP;
    System.assertEquals(ErpPointReqDto.Op.EXPIRY_OP, dto.op, 'op 필드 할당');
  }

  /* =====================================================
   * ExpiryRequest - 기본 생성자 : mbrPointUseModels 초기화 확인
   * ===================================================== */
  @IsTest
  static void test_expiryRequest_defaultConstructor() {
    ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();

    System.assertNotEquals(null, req.mbrPointUseModels, 'mbrPointUseModels 초기화됨');
    System.assertEquals(0, req.mbrPointUseModels.size(), '초기 리스트 크기 0');
  }

  /* =====================================================
   * ExpiryRequest - mbrPointUseModels 리스트에 항목 추가
   * ===================================================== */
  @IsTest
  static void test_expiryRequest_addItem() {
    ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();
    ErpPointReqDto.MbrPointUseModels item = new ErpPointReqDto.MbrPointUseModels();
    item.cd_save_ledger = 'LEDGER-001';
    item.pt_destory     = '500';
    item.cd_use_ledger  = 'USE-001';
    item.id_insert      = 'tester';
    req.mbrPointUseModels.add(item);

    System.assertEquals(1, req.mbrPointUseModels.size(), '항목 1건 추가');
    System.assertEquals('LEDGER-001', req.mbrPointUseModels[0].cd_save_ledger);
    System.assertEquals('500',        req.mbrPointUseModels[0].pt_destory);
  }

  /* =====================================================
   * MbrPointUseModels - 기본 생성자 : 필드 기본값 확인
   * ===================================================== */
  @IsTest
  static void test_mbrPointUseModels_defaultConstructor() {
    ErpPointReqDto.MbrPointUseModels m = new ErpPointReqDto.MbrPointUseModels();

    System.assertEquals('', m.cd_save_ledger, 'cd_save_ledger 기본값 빈 문자열');
    System.assertEquals('', m.pt_destory,     'pt_destory 기본값 빈 문자열');
    System.assertEquals('', m.cd_use_ledger,  'cd_use_ledger 기본값 빈 문자열');
    System.assertEquals('', m.id_insert,      'id_insert 기본값 빈 문자열');
  }

  /* =====================================================
   * MbrPointUseModels - 필드 직접 할당 후 읽기
   * ===================================================== */
  @IsTest
  static void test_mbrPointUseModels_fieldAssignment() {
    ErpPointReqDto.MbrPointUseModels m = new ErpPointReqDto.MbrPointUseModels();
    m.cd_save_ledger = 'SL-001';
    m.pt_destory     = '1000';
    m.cd_use_ledger  = 'UL-001';
    m.id_insert      = 'operator';

    System.assertEquals('SL-001',   m.cd_save_ledger);
    System.assertEquals('1000',     m.pt_destory);
    System.assertEquals('UL-001',   m.cd_use_ledger);
    System.assertEquals('operator', m.id_insert);
  }

  /* =====================================================
   * CreditRequest - 필드 직접 할당 후 읽기 (모든 필드 커버)
   * ===================================================== */
  @IsTest
  static void test_creditRequest_fieldAssignment_allFields() {
    ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();

    req.cd_company          = 'TC01';
    req.ym_create           = '202601';
    req.cd_type_point       = 'PURCHASE';
    req.dt_create           = '20260101';
    req.no_mbr              = 'MBR-001';
    req.no_sal              = 'SAL-001';
    req.am_sal              = 50000;
    req.pt_target           = 500;
    req.pt_use_sale         = 0;
    req.dt_save_plan        = '20260115';
    req.pt_save_plan        = 500;
    req.dt_save             = '20260115';
    req.pt_save             = 500;
    req.dt_limit_start      = '20260101';
    req.dt_limit_end        = '20261231';
    req.dt_destroy_plan     = '20261231';
    req.dt_destroy_del_sale = '';
    req.id_insert           = 'tester';
    req.cd_type_save        = '01';
    req.tx_remark           = '구매 포인트 적립';
    req.cd_save_ledger      = 'CREDIT-LEDGER-001';

    System.assertEquals('TC01',               req.cd_company);
    System.assertEquals('202601',             req.ym_create);
    System.assertEquals('PURCHASE',           req.cd_type_point);
    System.assertEquals('MBR-001',            req.no_mbr);
    System.assertEquals(50000,                req.am_sal);
    System.assertEquals(500,                  req.pt_target);
    System.assertEquals('20260115',           req.dt_save_plan);
    System.assertEquals('01',                 req.cd_type_save);
    System.assertEquals('구매 포인트 적립',     req.tx_remark);
    System.assertEquals('CREDIT-LEDGER-001',  req.cd_save_ledger);
  }

  /* =====================================================
   * CreditRequest - cd_type_save 코드 전체 커버
   * (01~06 코드 주석에 정의된 값 각각 확인)
   * ===================================================== */
  @IsTest
  static void test_creditRequest_cdTypeSave_allCodes() {
    List<String> codes = new List<String>{ '01', '02', '03', '04', '05', '06' };
    for (String code : codes) {
      ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();
      req.cd_type_save = code;
      System.assertEquals(code, req.cd_type_save, 'cd_type_save = ' + code);
    }
  }

  /* =====================================================
   * ExpiryRequest + MbrPointUseModels 복합 시나리오
   * ===================================================== */
  @IsTest
  static void test_expiryRequest_withMultipleItems() {
    ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();

    for (Integer i = 1; i <= 3; i++) {
      ErpPointReqDto.MbrPointUseModels item = new ErpPointReqDto.MbrPointUseModels();
      item.cd_save_ledger = 'SL-' + i;
      item.pt_destory     = String.valueOf(i * 100);
      item.cd_use_ledger  = 'UL-' + i;
      item.id_insert      = 'tester';
      req.mbrPointUseModels.add(item);
    }

    System.assertEquals(3, req.mbrPointUseModels.size(), '3건 추가');
    System.assertEquals('SL-1', req.mbrPointUseModels[0].cd_save_ledger);
    System.assertEquals('SL-3', req.mbrPointUseModels[2].cd_save_ledger);
    System.assertEquals('300',  req.mbrPointUseModels[2].pt_destory);
  }
}