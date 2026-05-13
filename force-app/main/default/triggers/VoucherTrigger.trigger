trigger VoucherTrigger on Voucher(after update) {
  try {
    System.debug('VoucherTrigger 진입');
    VoucherTriggerHandler handler = new VoucherTriggerHandler();
    handler.run();
  } catch (Exception e) {
  } finally {
  }
}