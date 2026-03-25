public interface GdProductCategoryService {
  /**
   * 제품 대분류 카테고리 등록/수정
   */
  ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData);

  /**
   * 제품 중분류 카테고리 등록/수정
   */
  ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData);

  /**
   * 제품 소분류 카테고리 등록/수정
   */
  ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData);
}