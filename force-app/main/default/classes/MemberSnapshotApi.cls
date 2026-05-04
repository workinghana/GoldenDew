@RestResource(urlMapping='/testSnapshot/*')
global with sharing class MemberSnapshotApi {
  private static final Integer MAX_CONTACTS = 10;
  private static final Integer MAX_LPMS = 20;
  private static final Integer MAX_JOURNALS = 500;
  private static final Integer MAX_ORDERS = 200;
  private static final Integer MAX_ORDER_ITEMS = 1000;
  private static final Integer MAX_VOUCHERS = 500;

  private static final Integer MAX_LOYALTY_LEDGERS = 500;
  private static final Integer MAX_LOYALTY_LEDGER_TRACEABILITIES = 1000;
  private static final Integer MAX_AGGR_SUB_POINT_EXPR_LEDGERS = 500;
  private static final Integer MAX_LOYALTY_MEMBER_CURRENCIES = 200;

  global class ApiResponse {
    // public Boolean success;
    // public String message;
    // public String memberNo;
    // public String phase;

    // public Integer contactCount;
    // public Integer loyaltyProgramMemberCount;
    // public Integer journalCount;
    // public Integer orderCount;
    // public Integer orderItemCount;
    // public Integer voucherCount;
    // public Integer loyaltyLedgerCount;
    // public Integer loyaltyLedgerTraceabilityCount;
    // public Integer loyaltyAggrSubPointExprLedgerCount;
    // public Integer loyaltyMemberCurrencyCount;

    // public Boolean contactsTruncated;
    // public Boolean lpmsTruncated;
    // public Boolean journalsTruncated;
    // public Boolean ordersTruncated;
    // public Boolean orderItemsTruncated;
    // public Boolean vouchersTruncated;
    // public Boolean loyaltyLedgersTruncated;
    // public Boolean loyaltyLedgerTraceabilitiesTruncated;
    // public Boolean loyaltyAggrSubPointExprLedgersTruncated;
    // public Boolean loyaltyMemberCurrenciesTruncated;

    public List<Contact> Contact = new List<Contact>();
    public List<LoyaltyProgramMember> LoyaltyProgramMember = new List<LoyaltyProgramMember>();
    public List<TransactionJournal> TransactionJournal = new List<TransactionJournal>();
    public List<Order> Order = new List<Order>();
    public List<OrderItem> OrderItem = new List<OrderItem>();
    public List<Voucher> Voucher = new List<Voucher>();

    public List<LoyaltyLedger> LoyaltyLedger = new List<LoyaltyLedger>();
    public List<LoyaltyLedgerTraceability> LoyaltyLedgerTraceability = new List<LoyaltyLedgerTraceability>();
    public List<LoyaltyAggrSubPointExprLedger__c> LoyaltyAggrSubPointExprLedger = new List<LoyaltyAggrSubPointExprLedger__c>();
    public List<LoyaltyMemberCurrency> LoyaltyMemberCurrency = new List<LoyaltyMemberCurrency>();
  }

  @HttpGet
  global static ApiResponse getMemberSnapshot() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    ApiResponse response = new ApiResponse();

    try {
      String memberNo = req.params.get('memberNo');

      if (String.isBlank(memberNo)) {
        res.statusCode = 400;
        // response.success = false;
        // response.message = 'memberNo is required.';
        return response;
      }

      //   memberNo = memberNo.trim();
      //   response.memberNo = memberNo;

      /* 1) Contact */
      //   response.phase = 'contacts';
      response.Contact = [
        SELECT
          Id,
          IsDeleted,
          MasterRecordId,
          AccountId,
          LastName,
          FirstName,
          Salutation,
          MiddleName,
          Suffix,
          Name,
          MailingStreet,
          MailingCity,
          MailingState,
          MailingPostalCode,
          MailingCountry,
          MailingLatitude,
          MailingLongitude,
          MailingGeocodeAccuracy,
          MailingAddress,
          Phone,
          Fax,
          MobilePhone,
          HomePhone,
          OtherPhone,
          AssistantPhone,
          ReportsToId,
          Email,
          Title,
          Department,
          Birthdate,
          OwnerId,
          CreatedDate,
          CreatedById,
          LastModifiedDate,
          LastModifiedById,
          SystemModstamp,
          LastActivityDate,
          LastCURequestDate,
          LastCUUpdateDate,
          LastViewedDate,
          LastReferencedDate,
          EmailBouncedReason,
          EmailBouncedDate,
          IsEmailBounced,
          PhotoUrl,
          Jigsaw,
          JigsawContactId,
          IndividualId,
          GenderIdentity,
          IsPriorityRecord,
          ContactSource,
          TitleType,
          DepartmentGroup,
          BuyerAttributes,
          Grade__c,
          IsMobileVerified__c,
          IsWithdrawn__c,
          CreatedDatetime__c,
          IsMarried__c,
          IsEmailAgreed__c,
          IsSMSAgreed__c,
          IsMagazineSubscribed__c,
          WeddingAnniversaryDate__c,
          MemberNo__c,
          et4ae5__HasOptedOutOfMobile__c,
          et4ae5__Mobile_Country_Code__c,
          FirstPurchaseDate__c,
          LastPurchaseDate__c,
          StoreRegi__c,
          StoreMana__c,
          MagazineSubscriptionDate__c,
          MemberType__c,
          MemberJoinDate__c,
          MemberDropDate__c,
          PreviousGrade__c,
          ExpectedGrade__c,
          TierQualifyingSpend3Y__c
        FROM Contact
        WHERE MemberNo__c = :memberNo
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
      //   response.contactsTruncated = response.contacts.size() == MAX_CONTACTS;

      Set<Id> contactIds = new Set<Id>();
      for (Contact c : response.Contact) {
        contactIds.add(c.Id);
      }

      /* 2) LoyaltyProgramMember */
      Set<Id> lpmIds = new Set<Id>();
      if (!contactIds.isEmpty()) {
        // response.phase = 'loyaltyProgramMembers';`
        response.LoyaltyProgramMember = [
          SELECT
            Id,
            OwnerId,
            IsDeleted,
            MembershipNumber,
            CreatedDate,
            CreatedById,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            LastViewedDate,
            LastReferencedDate,
            ContactId,
            ProgramId,
            MemberType,
            EnrollmentChannel,
            StatementMethod,
            StatementFrequency,
            CanReceivePromotions,
            CanReceivePartnerPromotions,
            ReferredById,
            EnrollmentDate,
            MembershipEndDate,
            MembershipLastRenewalDate,
            MemberStatus,
            LastActivityDate,
            AccountId,
            RelatedCorporateMembershipId,
            StatementLastGeneratedDate,
            GroupName,
            GroupCreatedByMemberId,
            ReferralCode,
            IsEligibleForTierAssessment,
            F_Name__c,
            F_Grade__c,
            MemberType__c,
            F_Email__c,
            F_MobilePhone__c,
            F_Birthdate__c,
            F_GenderIdentity__c,
            F_IsSMSAgreed__c,
            F_StoreMana__c,
            F_PreviousGrade__c,
            F_MemberJoinDate__c,
            F_TierQualifyingSpend3Y__c,
            F_ExpectedGrade__c,
            MembershipNumber__c
          FROM LoyaltyProgramMember
          WHERE ContactId IN :contactIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_LPMS
        ];
        // response.lpmsTruncated = response.loyaltyProgramMembers.size() == MAX_LPMS;

        for (LoyaltyProgramMember lpm : response.LoyaltyProgramMember) {
          lpmIds.add(lpm.Id);
        }
      }

      /* 3) TransactionJournal */
      if (!lpmIds.isEmpty()) {
        // response.phase = 'transactionJournals';
        response.TransactionJournal = [
          SELECT
            Id,
            Name,
            IsDeleted,
            CreatedById,
            CreatedDate,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            MemberId,
            JournalTypeId,
            JournalSubTypeId,
            ActivityDate,
            JournalDate,
            ErrorDescription,
            Status,
            ExternalTransactionNumber,
            UsageType,
            Origin,
            Destination,
            TransactionLocation,
            Distance,
            BookedFareClass,
            TraveledFareClass,
            Brand,
            BookedRoomType,
            BookingDate,
            InvoiceDate,
            StartDate,
            EndDate,
            Channel,
            TransactionAmount,
            PaymentMethod,
            PartnerId,
            FlightNumber,
            Establishment,
            Quantity,
            QuantityUnitOfMeasureId,
            ProductId,
            ProductCategoryId,
            OrderId,
            OrderItemId,
            Industry,
            ReferredMemberId,
            RelatedCorporateMembershipId,
            RelatedJournalId,
            LoyaltyProgramId,
            JournalReason,
            VoucherCode,
            PromotionId,
            EscrowPointsCreditDate,
            RedeemedPointsExpirationInformation,
            ReferredPartyId,
            IsParentTransaction,
            TotalPromotionDiscount,
            EngagementChannelTypeId,
            UniqueIdentifier,
            LastViewedDate,
            LastReferencedDate,
            TransactionDate__c,
            CS_CHANNEL1_F_CODE__c,
            CS_CHANNEL2_F_CODE__c,
            CS_Sentdate__c,
            F_JST_Description__c,
            DepositType__c,
            SaleId__c,
            OrderId__c,
            DepositNo__c,
            DeposiSeqNo__c,
            InsertId__c,
            JournalTypeName__c,
            JournalSubTypeName__c,
            JournalReason__c,
            DeleteDateTime__c,
            IsDeleted__c,
            AdditionalNotes__c,
            PostPointBalance__c,
            UsageType__c,
            Magazine_uuid__c,
            Magazine_ApplicationDate__c,
            CS_CHANNEL1__c,
            Magazine_Address__c,
            IsPointUnavailable__c,
            Magazine_A_Name__c,
            Magazine_A_MobilePhone__c,
            Magazine_A_Birthdate__c,
            CS_Content__c,
            Magazine_Grade__c,
            Magazine_A_ZIP_Code__c,
            Magazine_A_Sub_Reason__c,
            Magazine_Response_Time__c,
            Magazine_PUR_10YEAR_YN__c,
            CS_CHANNEL2__c,
            Magazine_Ismagazinesubscribed__c,
            Magazine_Season__c,
            Magazine_StoreMana__c,
            Magazine_MemberType__c,
            Magazine_EXI_SUB_YN__c,
            Magazine_SentDate__c,
            Magazine_Thisyear__c,
            Magazine_A_sns_YN__c,
            Magazine_A_account_YN__c,
            Magazine_YN_NEWJOIN__c,
            Magazine_IsUpdated__c,
            CS_CAMP_NAME__c,
            CS_CAMP_DTL_NAME__c,
            CS_JOURNEY_ID__c,
            CS_ACTIVITY_ID__c
          FROM TransactionJournal
          WHERE MemberId IN :lpmIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_JOURNALS
        ];
        // response.journalsTruncated = response.transactionJournals.size() == MAX_JOURNALS;
      }

      Set<Id> transactionJournalIds = new Set<Id>();
      for (TransactionJournal tj : response.TransactionJournal) {
        transactionJournalIds.add(tj.Id);
      }

      /* 4) LoyaltyMemberCurrency */
      if (!lpmIds.isEmpty()) {
        // response.phase = 'loyaltyMemberCurrencies';
        response.LoyaltyMemberCurrency = [
          SELECT
            Id,
            IsDeleted,
            Name,
            CreatedDate,
            CreatedById,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            LastViewedDate,
            LastReferencedDate,
            LoyaltyMemberId,
            LoyaltyProgramCurrencyId,
            TotalPointsAccrued,
            TotalPointsRedeemed,
            TotalPointsExpired,
            ExpirablePoints,
            PointsBalance,
            NextResetDate,
            LastExpirationProcessRunDate,
            LastResetDate,
            BalanceBeforeReset,
            LastAccrualProcessedDate,
            TotalEscrowPointsAccrued,
            TotalEscrowRolloverPoints,
            EscrowPointsBalance,
            LastEscrowProcessedDate,
            PointsBalBeforeSecondLastReset,
            RedemStlPendFromDateTime,
            LastExpiredPtTraceabilityRunDt
          FROM LoyaltyMemberCurrency
          WHERE LoyaltyMemberId IN :lpmIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_LOYALTY_MEMBER_CURRENCIES
        ];
        // response.loyaltyMemberCurrenciesTruncated = response.loyaltyMemberCurrencies.size() == MAX_LOYALTY_MEMBER_CURRENCIES;
      }

      /* 5) LoyaltyLedger */
      Set<Id> loyaltyLedgerIds = new Set<Id>();
      if (!lpmIds.isEmpty()) {
        // response.phase = 'loyaltyLedgers';
        response.LoyaltyLedger = [
          SELECT
            Id,
            IsDeleted,
            CreatedById,
            CreatedDate,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            LoyaltyProgramMemberId,
            LoyaltyProgramCurrencyId,
            TransactionJournalId,
            ActivityDate,
            ExpiryDate,
            EventType,
            Correlation,
            Flow,
            Points,
            AdditionalNotes,
            PromotionId,
            EscrowPointsCreditDate,
            LoyaltyPgmCrcySubtypeId,
            LastViewedDate,
            LastReferencedDate
          FROM LoyaltyLedger
          WHERE LoyaltyProgramMemberId IN :lpmIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_LOYALTY_LEDGERS
        ];
        // response.loyaltyLedgersTruncated = response.loyaltyLedgers.size() == MAX_LOYALTY_LEDGERS;

        for (LoyaltyLedger ll : response.LoyaltyLedger) {
          loyaltyLedgerIds.add(ll.Id);
        }
      }

      /* 6) LoyaltyLedgerTraceability */
      if (!loyaltyLedgerIds.isEmpty()) {
        // response.phase = 'loyaltyLedgerTraceabilities';
        response.LoyaltyLedgerTraceability = [
          SELECT
            Id,
            OwnerId,
            IsDeleted,
            Name,
            CreatedDate,
            CreatedById,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            LastViewedDate,
            LastReferencedDate,
            CreditLoyaltyLedgerId,
            DebitLoyaltyLedgerId,
            ActionType,
            Points,
            LoyaltyProgramCurrencyId,
            LoyaltyPgmCurrencySubtypeId,
            LoyaltyProgramMemberId
          FROM LoyaltyLedgerTraceability
          WHERE LoyaltyProgramMemberId IN :lpmIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_LOYALTY_LEDGER_TRACEABILITIES
        ];
        // response.loyaltyLedgerTraceabilitiesTruncated = response.loyaltyLedgerTraceabilities.size() == MAX_LOYALTY_LEDGER_TRACEABILITIES;
      }

      /* 7) LoyaltyAggrSubPointExprLedger__c */
      if (!lpmIds.isEmpty() || !transactionJournalIds.isEmpty()) {
        // response.phase = 'loyaltyAggrSubPointExprLedgers';
        response.LoyaltyAggrSubPointExprLedger = [
          SELECT
            Id,
            IsDeleted,
            Name,
            CreatedDate,
            CreatedById,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            LoyaltyProgramMemberId__c,
            CurrencySubTypeId__c,
            AccruedPoints__c,
            ExpiryDate__c,
            RedeemedPoints__c,
            ExpiredPoints__c,
            LoyaltyProgramCurrencyId__c,
            CurrencySubTypeName__c,
            isExpired__c,
            AvailablePoints__c
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE LoyaltyProgramMemberId__c IN :lpmIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_AGGR_SUB_POINT_EXPR_LEDGERS
        ];
        // response.loyaltyAggrSubPointExprLedgersTruncated = response.loyaltyAggrSubPointExprLedgers.size() == MAX_AGGR_SUB_POINT_EXPR_LEDGERS;
      }

      /* 8) Order */
      //   response.phase = 'orders';
      response.Order = [
        SELECT
          Id,
          OwnerId,
          ContractId,
          AccountId,
          Pricebook2Id,
          OriginalOrderId,
          EffectiveDate,
          EndDate,
          IsReductionOrder,
          Status,
          Description,
          CustomerAuthorizedById,
          CompanyAuthorizedById,
          Type,
          BillingStreet,
          BillingCity,
          BillingState,
          BillingPostalCode,
          BillingCountry,
          BillingLatitude,
          BillingLongitude,
          BillingGeocodeAccuracy,
          BillingAddress,
          ShippingStreet,
          ShippingCity,
          ShippingState,
          ShippingPostalCode,
          ShippingCountry,
          ShippingLatitude,
          ShippingLongitude,
          ShippingGeocodeAccuracy,
          ShippingAddress,
          Name,
          ActivatedDate,
          ActivatedById,
          StatusCode,
          OrderNumber,
          TotalAmount,
          CreatedDate,
          CreatedById,
          LastModifiedDate,
          LastModifiedById,
          IsDeleted,
          SystemModstamp,
          LastViewedDate,
          LastReferencedDate,
          ActualPaymentAmount__c,
          OrderNo__c,
          SaleNo__c,
          MemberNo__c,
          SaleStatus__c,
          OrderStatus__c,
          StoreCode__c,
          DeleteDateTime__c,
          InsertId__c,
          IsDeleted__c,
          RU_OrderItemLineCount__c,
          F_MemberNo__c,
          IsReductionOrder__c,
          OriginalOrderId__c,
          StoreName__c
        FROM Order
        WHERE MemberNo__c IN :contactIds
        ORDER BY CreatedDate DESC
        LIMIT :MAX_ORDERS
      ];
      //   response.ordersTruncated = response.orders.size() == MAX_ORDERS;

      Set<Id> orderIds = new Set<Id>();
      for (Order o : response.Order) {
        orderIds.add(o.Id);
      }

      /* 9) OrderItem */
      if (!orderIds.isEmpty()) {
        // response.phase = 'orderItems';
        response.OrderItem = [
          SELECT
            Id,
            Product2Id,
            IsDeleted,
            OrderId,
            PricebookEntryId,
            OriginalOrderItemId,
            AvailableQuantity,
            Quantity,
            UnitPrice,
            ListPrice,
            TotalPrice,
            ServiceDate,
            EndDate,
            Description,
            CreatedDate,
            CreatedById,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            OrderItemNumber,
            Status__c,
            SaleSeqNo__c,
            OrderSeqNo__c,
            OrderId__c,
            OrderItemNo__c,
            SaleItemNo__c,
            DeleteDateTime__c,
            IsExclude__c,
            DiscountRate__c,
            NetSalesUnitPrice__c,
            OriginalOrderItemId__c,
            Field1__c
          FROM OrderItem
          WHERE OrderId IN :orderIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_ORDER_ITEMS
        ];
        // response.orderItemsTruncated = response.orderItems.size() == MAX_ORDER_ITEMS;
      }

      /* 10) Voucher */
      if (!contactIds.isEmpty() || !lpmIds.isEmpty()) {
        // response.phase = 'vouchers';
        response.Voucher = [
          SELECT
            Id,
            OwnerId,
            IsDeleted,
            Name,
            CreatedDate,
            CreatedById,
            LastModifiedDate,
            LastModifiedById,
            SystemModstamp,
            LastViewedDate,
            LastReferencedDate,
            VoucherDefinitionId,
            ExpirationDate,
            Status,
            DiscountPercent,
            FaceValue,
            LoyaltyProgramMemberId,
            ContactId,
            AccountId,
            VoucherCode,
            EffectiveDate,
            UseDate,
            TransactionJournalId,
            Reason,
            BenefitId,
            PromotionId,
            RedeemedValue,
            RemainingValue,
            EffectiveDateTime,
            ExpirationDateTime,
            ReservationKey,
            ReservedDateTime,
            ReservedValue,
            UsedTransactionJournalId__c,
            ProcessResult__c,
            VoucherName__c
          FROM Voucher
          WHERE ContactId IN :contactIds OR LoyaltyProgramMemberId IN :lpmIds
          ORDER BY CreatedDate DESC
          LIMIT :MAX_VOUCHERS
        ];
        // response.vouchersTruncated = response.vouchers.size() == MAX_VOUCHERS;
      }

      //   response.contactCount = response.contacts.size();
      //   response.loyaltyProgramMemberCount = response.loyaltyProgramMembers.size();
      //   response.journalCount = response.transactionJournals.size();
      //   response.orderCount = response.orders.size();
      //   response.orderItemCount = response.orderItems.size();
      //   response.voucherCount = response.vouchers.size();
      //   response.loyaltyLedgerCount = response.loyaltyLedgers.size();
      //   response.loyaltyLedgerTraceabilityCount = response.loyaltyLedgerTraceabilities.size();
      //   response.loyaltyAggrSubPointExprLedgerCount = response.loyaltyAggrSubPointExprLedgers.size();
      //   response.loyaltyMemberCurrencyCount = response.loyaltyMemberCurrencies.size();

      //   response.success = true;
      //   response.message = 'success';
      res.statusCode = 200;
      return response;
    } catch (Exception e) {
      res.statusCode = 500;
      //   response.success = false;
      //   response.message = e.getMessage();
      return response;
    }
  }
}