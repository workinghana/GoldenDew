/**
 * ERP Promotion Point API Client
 * - CommonApiClient 기반
 * - 토큰 캐시/401 갱신 로직은 CommonApiClient + NamedCredentialTokenRefresher에 위임
 *
 * @author
 * @since 2026-02-05
 */
public with sharing class ErpPromotionPointApiClient {

    // =========================
    // Config
    // =========================
    private static final String ERP_NC = 'GoldenDewApiNC';
    private static final String TOKEN_CACHE_KEY = 'GOLDENDEW';
    private static final Integer DEFAULT_TIMEOUT_MS = 60000;

    // =========================
    // API Paths
    // =========================
    private static final String PROMOTION_POINT_MASTER_PATH =
        '/Crm/PromotionPoint'; // 프로모션 포인트 등록/수정/삭제

    // =========================
    // Public Methods
    // =========================

    /** 프로모션 포인트 등록 */
    public static ErpApiResponseDto createPromotionPoint(
        ErpPromotionPointReqDto.CreateRequest req
    ) {
        if (req == null) {
            throw new IllegalArgumentException('Request body is required.');
        }

        CommonApiClient.RequestOptions opt =
            baseOptions('POST', ncEndpoint(PROMOTION_POINT_MASTER_PATH));

        opt.body = req;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
        return ErpApiResponseDto.fromWrapper(res);
    }

    /** 프로모션 포인트 수정 */
    public static ErpApiResponseDto updatePromotionPoint(
        ErpPromotionPointReqDto.UpdateRequest req
    ) {
        if (req == null) {
            throw new IllegalArgumentException('Request body is required.');
        }

        CommonApiClient.RequestOptions opt =
            baseOptions('PATCH', ncEndpoint(PROMOTION_POINT_MASTER_PATH));

        opt.body = req;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
        return ErpApiResponseDto.fromWrapper(res);
    }

    /** 프로모션 포인트 삭제 */
    public static ErpApiResponseDto deletePromotionPoint(
        ErpPromotionPointReqDto.DeleteRequest req
    ) {
        if (req == null) {
            throw new IllegalArgumentException('Request body is required.');
        }

        CommonApiClient.RequestOptions opt =
            baseOptions('DELETE', ncEndpoint(PROMOTION_POINT_MASTER_PATH));

        opt.query.put('no_prom', req.no_prom);
        opt.query.put('no_prom_point', req.no_prom_point);
        opt.query.put('id_delete', req.id_delete);

        // DELETE는 body 미사용
        opt.body = null;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
        return ErpApiResponseDto.fromWrapper(res);
    }

    // =========================
    // Internal Helpers
    // =========================

    /** 공통 옵션 생성 */
    private static CommonApiClient.RequestOptions baseOptions(
        String method,
        String endpoint
    ) {
        CommonApiClient.RequestOptions opt =
            new CommonApiClient.RequestOptions();

        opt.method = method;
        opt.endpoint = endpoint;
        opt.timeoutMs = DEFAULT_TIMEOUT_MS;

        opt.maxRetries = 2;
        opt.throwOnHttpError = true;
        opt.parseJson = true;

        // 토큰 캐시
        opt.tokenCacheKey = TOKEN_CACHE_KEY;
        opt.tokenSkewSeconds = 60;
        opt.refreshTokenOn401 = false;

        // 기본 헤더
        opt.headers.put('Accept', 'application/json');
        opt.headers.put('Content-Type', 'application/json');

        return opt;
    }

    /** Named Credential endpoint 생성 */
    private static String ncEndpoint(String path) {
        return 'callout:' + ERP_NC + path;
    }
}