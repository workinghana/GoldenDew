/**
 * 멤버 관련 비동기 Job (통합)
 * - 멤버에 관련한 작업을 하나의 Queueable로 처리
 */
public class ErpMemberJob extends ErpAsyncJob {
  // 어떤 작업인지 구분
  public enum Operation {
    UPDATE_GRADE, // 등급 변경
    UPDATE_MAGAZINE_SUBSCRIPTION, // 회원 매거진 구독 정보 변경
    UPDATE_MEMBER_SMS_RECEIVE // 회원 SMS 수신 여부 변경
  }

  private Operation op;

  public ErpMemberJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    super(String.valueOf(op), requestDto, callback, recordId);
    this.op = op;
    // this.requestJson = (requestDto == null) ? null : JSON.serialize(requestDto);
  }

  public ErpMemberJob(Operation op, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
    super(String.valueOf(op), requestDto, callback, recordIds);
    this.op = op;
    // this.requestJson = (requestDto == null) ? null : JSON.serialize(requestDto);
  }

  public ErpMemberJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
    super(String.valueOf(op), requestDto, callback, recordId, o);
    this.op = op;
  }

  protected override ErpApiResponseDto doCallout() {
    System.debug('doCallout 진입. op=' + String.valueOf(op) + ', requestDto=' + JSON.serialize(requestDto));
    // Operation별로 요청 DTO를 복원해서 ErpMemberApiClient 동기 메서드 호출
    switch on op {
      // 회원 등급 변경 (벌크)
      when UPDATE_GRADE {
        System.debug('when UPDATE_GRADE 진입');
        return ErpMemberApiClient.updateGrade((ErpMemberReqDto.UpdateGradeRequest) requestDto);
      }
      // 회원 SMS 수신 여부 변경
      when UPDATE_MEMBER_SMS_RECEIVE {
        System.debug('when UPDATE_MEMBER_SMS_RECEIVE 진입');
        return ErpMemberApiClient.updateMemberSmsReceive((ErpMemberReqDto.UpdateMemberSmsReceiveRequest) requestDto);
      }
      // 회원 매거진 구독 정보 변경 (벌크)
      when UPDATE_MAGAZINE_SUBSCRIPTION {
        ErpMemberReqDto.UpdateMagazineSubscriptionRequest req = (ErpMemberReqDto.UpdateMagazineSubscriptionRequest) requestDto;

        if (req == null || req.memebrModelList == null || req.memebrModelList.isEmpty()) {
          return new ErpApiResponseDto(); // 또는 null 정책
        }

        Integer chunkSize = 200; // 운영 기준
        ErpApiResponseDto lastRes;

        for (Integer i = 0; i < req.memebrModelList.size(); i += chunkSize) {
          Integer endIdx = Math.min(i + chunkSize, req.memebrModelList.size());

          ErpMemberReqDto.UpdateMagazineSubscriptionRequest chunk = new ErpMemberReqDto.UpdateMagazineSubscriptionRequest();
          chunk.ID_UPDATE = req.ID_UPDATE;

          for (Integer j = i; j < endIdx; j++) {
            chunk.memebrModelList.add(req.memebrModelList[j]);
          }

          lastRes = ErpMemberApiClient.updateMemberMagazineSubscription(chunk);
        }

        return lastRes;
      }
    }

    // switch exhaustiveness 대비(컴파일러가 막아주긴 함)
    throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  }
}