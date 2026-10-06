# Payment Rules
Keep platform-fee payments separate from event/vendor payment records. Vendor platform fee: backend determines fee → creates Razorpay order → checkout → backend verifies signature/payment → records transaction → advances submission. Razorpay secrets remain server-side. Never trust client success callbacks without backend verification.
