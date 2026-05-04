@IsTest
private class CsResDtoTest {
  @IsTest
  static void test_constructor_sets_default_values() {
    CsResDto dto = new CsResDto();

    System.assertEquals('AD004', dto.storeCode);
    System.assertEquals('IMC팀', dto.storeName);
    System.assertEquals(null, dto.sentDate);
    System.assertEquals(null, dto.type);
    System.assertEquals('기타', dto.content);
    System.assertEquals(null, dto.detailContent);
  }

  @IsTest
  static void test_public_fields_are_assignable() {
    CsResDto dto = new CsResDto();

    dto.sentDate = '20260309';
    dto.type = 'ETC';
    dto.content = '기타';
    dto.detailContent = '테스트상세';

    System.assertEquals('20260309', dto.sentDate);
    System.assertEquals('ETC', dto.type);
    System.assertEquals('기타', dto.content);
    System.assertEquals('테스트상세', dto.detailContent);
    System.assertEquals('AD004', dto.storeCode);
    System.assertEquals('IMC팀', dto.storeName);
  }
}