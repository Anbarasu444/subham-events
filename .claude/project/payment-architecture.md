# Payment Architecture
Platform fee: Vendor → backend-created Razorpay order → Razorpay → backend verification → platform_fee_transactions → listing submission review.
Event payment: User/EventVendor/Booking → payment transaction records. Keep these domains separate.
