describe("AUTH / OTP GENERATE", () => {
  function generateOtp() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  it("should generate 6 digit OTP", () => {
    const otp = generateOtp();

    expect(otp).toHaveLength(6);
    expect(Number.isNaN(Number(otp))).toBe(false);
  });

  it("should generate different OTPs", () => {
    const otp1 = generateOtp();
    const otp2 = generateOtp();

    expect(otp1).not.toBe(otp2);
  });
});
