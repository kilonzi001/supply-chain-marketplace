module supply_chain::supply_chain {
    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Option, none, some, is_some, contains, borrow};
    // Errors
    const EInvalidOrder: u64 = 1;
    const EInvalidProduct: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotSupplier: u64 = 5;
    const EInvalidWithdrawal: u64 = 6;
    const EDeadlinePassed: u64 = 7;
    const EInsufficientEscrow: u64 = 8;
    const ENotBuyer: u64 = 9;
    const EOrderNotFulfilled: u64 = 10;
    const EOrderAlreadyFulfilled: u64 = 11;
    // Struct definitions
    struct Order has key, store {
        id: UID,
        buyer: address,
        product: vector<u8>,
        quantity: u64,
        price: u64,
        escrow: Balance<SUI>,
        dispute: bool,
        rating: Option<u64>,
        status: vector<u8>,
        supplier: Option<address>,
        orderFulfilled: bool,
        created_at: u64,
        deadline: u64,
    }
    struct ProductRecord has key, store {
        id: UID,
        buyer: address,
        review: vector<u8>,
    }
    // Accessors
    public fun get_product(order: &Order): vector<u8> {
        order.product
    }
    public fun get_order_price(order: &Order): u64 {
        order.price
    }
    public fun get_order_status(order: &Order): vector<u8> {
        order.status
    }
    public fun get_order_deadline(order: &Order): u64 {
        order.deadline
    }
    // Public - Entry functions
    // Create a new order
    public entry fun create_order(product: vector<u8>, quantity: u64, price: u64, clock: &Clock, duration: u64, open: vector<u8>, ctx: &mut TxContext) {
        let order_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + duration;
        transfer::share_object(Order {
            id: order_id,
            buyer: tx_context::sender(ctx),
            supplier: none(),
            product: product,
            quantity: quantity,
            rating: none(),
            status: open,
            price: price,
            escrow: balance::zero(),
            orderFulfilled: false,
            dispute: false,
            created_at: clock::timestamp_ms(clock),
            deadline: deadline,
        });
    }
    // Supplier accepts the order
    public entry fun accept_order(order: &mut Order, ctx: &mut TxContext) {
        assert!(!is_some(&order.supplier), EInvalidOrder);
        order.supplier = some(tx_context::sender(ctx));
    }
    // Fulfill order
    public entry fun fulfill_order(order: &mut Order, clock: &Clock, ctx: &mut TxContext) {
        assert!(contains(&order.supplier, &tx_context::sender(ctx)), ENotSupplier);
        assert!(clock::timestamp_ms(clock) < order.deadline, EDeadlinePassed);
        order.orderFulfilled = true;
    }
    // Mark order as complete
    public entry fun mark_order_complete(order: &mut Order, ctx: &mut TxContext) {
        assert!(contains(&order.supplier, &tx_context::sender(ctx)), ENotSupplier);
        assert!(!order.orderFulfilled, EOrderAlreadyFulfilled);
        order.orderFulfilled = true;
    }
    // Raise a dispute
    public entry fun dispute_order(order: &mut Order, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        assert!(!order.dispute, EAlreadyResolved);
        order.dispute = true;
    }
    // Resolve dispute if any between buyer and supplier
    public entry fun resolve_dispute(order: &mut Order, resolved: bool, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        assert!(order.dispute, EAlreadyResolved);
        assert!(is_some(&order.supplier), EInvalidOrder);
        let escrow_amount = balance::value(&order.escrow);
        let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
        if (resolved) {
            let supplier = *borrow(&order.supplier);
            transfer::public_transfer(escrow_coin, supplier);
        } else {
            transfer::public_transfer(escrow_coin, order.buyer);
        }
        order.supplier = none();
        order.orderFulfilled = false;
        order.dispute = false;
    }
    // Release payment to the supplier after order is fulfilled
    public entry fun release_payment(order: &mut Order, clock: &Clock, review: vector<u8>, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        assert!(order.orderFulfilled && !order.dispute, EOrderNotFulfilled);
        assert!(clock::timestamp_ms(clock) > order.deadline, EDeadlinePassed);
        assert!(is_some(&order.supplier), EInvalidOrder);
        let supplier = *borrow(&order.supplier);
        let escrow_amount = balance::value(&order.escrow);
        assert!(escrow_amount > 0, EInsufficientEscrow);
        let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, supplier);
        let productRecord = ProductRecord {
            id: object::new(ctx),
            buyer: tx_context::sender(ctx),
            review: review,
        };
        transfer::public_transfer(productRecord, tx_context::sender(ctx));
        order.supplier = none();
        order.orderFulfilled = false;
        order.dispute = false;
    }
    // Add more cash at escrow
    public entry fun add_funds(order: &mut Order, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == order.buyer, ENotBuyer);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut order.escrow, added_balance);
    }
    // Cancel order
    public entry fun cancel_order(order: &mut Order, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx) || contains(&order.supplier, &tx_context::sender(ctx)), ENotBuyer);
        if (is_some(&order.supplier) && !order.orderFulfilled && !order.dispute) {
            let escrow_amount = balance::value(&order.escrow);
            let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, order.buyer);
        }
        order.supplier = none();
        order.orderFulfilled = false;
        order.dispute = false;
    }
    // Rate the supplier
    public entry fun rate_supplier(order: &mut Order, rating: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        assert!(order.orderFulfilled, EOrderNotFulfilled);
        order.rating = some(rating);
    }
    // Update product
    public entry fun update_product(order: &mut Order, new_product: vector<u8>, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        order.product = new_product;
    }
    // Update order price
    public entry fun update_order_price(order: &mut Order, new_price: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        order.price = new_price;
    }
    // Update quantity
    public entry fun update_order_quantity(order: &mut Order, new_quantity: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        order.quantity = new_quantity;
    }
    // Update deadline
    public entry fun update_order_deadline(order: &mut Order, new_deadline: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        order.deadline = new_deadline;
    }
    // Update order status
    public entry fun update_order_status(order: &mut Order, completed: vector<u8>, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        order.status = completed;
    }
    // Add more cash to escrow
    public entry fun add_funds_to_order(order: &mut Order, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == order.buyer, ENotBuyer);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut order.escrow, added_balance);
    }
    // Withdraw funds from escrow
    public entry fun request_refund(order: &mut Order, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == order.buyer, ENotBuyer);
        assert!(!order.orderFulfilled && !order.dispute, EInvalidWithdrawal);
        let escrow_amount = balance::value(&order.escrow);
        let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, order.buyer);
        order.supplier = none();
        order.orderFulfilled = false;
        order.dispute = false;
    }
    // Extend order deadline
    public entry fun extend_order_deadline(order: &mut Order, additional_time: u64, ctx: &mut TxContext) {
        assert!(contains(&order.supplier, &tx_context::sender(ctx)), ENotSupplier);
        order.deadline = order.deadline + additional_time;
    }
    // Modify review
    public entry fun modify_review(order: &mut Order, new_review: vector<u8>, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        let productRecord = ProductRecord {
            id: object::new(ctx),
            buyer: tx_context::sender(ctx),
            review: new_review,
        };
        transfer::public_transfer(productRecord, tx_context::sender(ctx));
    }
}