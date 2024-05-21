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

    // Struct definitions

    // Order struct
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

    // ProductRecord struct
    struct ProductRecord has key, store {
        id: UID,
        buyer: address,
        review: vector<u8>,
    }

    // Accessors
    public entry fun get_product(order: &Order): vector<u8> {
        order.product
    }

    public entry fun get_order_price(order: &Order): u64 {
        order.price
    }

    public entry fun get_order_status(order: &Order): vector<u8> {
        order.status
    }

    public entry fun get_order_deadline(order: &Order): u64 {
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
            supplier: none(), // Set to an initial value, can be updated later
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

    // Mark order as fulfilled
    public entry fun mark_order_fulfilled(order: &mut Order, clock: &Clock, ctx: &mut TxContext) {
        assert!(contains(&order.supplier, &tx_context::sender(ctx)), EInvalidProduct);
        assert!(clock::timestamp_ms(clock) < order.deadline, EDeadlinePassed);
        order.orderFulfilled = true;
    }

    // Mark order as complete
    public entry fun mark_order_complete(order: &mut Order, ctx: &mut TxContext) {
        assert!(contains(&order.supplier, &tx_context::sender(ctx)), ENotSupplier);
        order.orderFulfilled = true;
    }

    // Raise a dispute
    public entry fun dispute_order(order: &mut Order, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), EDispute);
        order.dispute = true;
    }

    // Transfer funds from escrow to the supplier
    fun transfer_funds_to_supplier(order: &mut Order, ctx: &mut TxContext) {
        let supplier = *borrow(&order.supplier);
        let escrow_amount = balance::value(&order.escrow);
        let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, supplier);
    }

    // Reset the order state
    fun reset_order_state(order: &mut Order) {
        order.supplier = none();
        order.orderFulfilled = false;
        order.dispute = false;
    }

    // Resolve dispute if any between buyer and supplier
    public entry fun resolve_dispute(order: &mut Order, resolved: bool, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), EDispute);
        assert!(order.dispute, EAlreadyResolved);
        assert!(is_some(&order.supplier), EInvalidOrder);

        if (resolved) {
            transfer_funds_to_supplier(order, ctx);
        } else {
            let escrow_amount = balance::value(&order.escrow);
            let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, order.buyer);
        }

        reset_order_state(order);
    }

    // Release payment to the supplier after order is fulfilled
    public entry fun release_payment(order: &mut Order, clock: &Clock, review: vector<u8>, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotSupplier);
        assert!(order.orderFulfilled && !order.dispute, EInvalidProduct);
        assert!(clock::timestamp_ms(clock) > order.deadline, EDeadlinePassed);
        assert!(is_some(&order.supplier), EInvalidOrder);
        assert!(balance::value(&order.escrow) > 0, EInsufficientEscrow); // Ensure there are enough funds in escrow

        transfer_funds_to_supplier(order, ctx);

        // Create a new product record
        let productRecord = ProductRecord {
    id: object::new(ctx),
    buyer: tx_context::sender(ctx),
    review: review,
};

// Change accessibility of product record
transfer::public_transfer(productRecord, tx_context::sender(ctx));

reset_order_state(order);
    }

    // Add more cash to escrow
    public entry fun add_funds(order: &mut Order, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == order.buyer, ENotSupplier);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut order.escrow, added_balance);
    }

    // Cancel order
    public entry fun cancel_order(order: &mut Order, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx) || contains(&order.supplier, &tx_context::sender(ctx)), ENotSupplier);

        // Refund funds to the buyer if not yet paid
        if (is_some(&order.supplier) && !order.orderFulfilled && !order.dispute) {
            let escrow_amount = balance::value(&order.escrow);
            let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, order.buyer);
        }

        reset_order_state(order);
    }

    // Rate the supplier
    public entry fun rate_supplier(order: &mut Order, rating: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotSupplier);
        order.rating = some(rating);
    }

    // Update product
    public entry fun update_product(order: &mut Order, new_product: vector<u8>, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotSupplier);
        order.product = new_product;
    }

    // Update order price
    public entry fun update_order_price(order: &mut Order, new_price: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotSupplier);
        order.price = new_price;
    }

    // Update quantity
    public entry fun update_order_quantity(order: &mut Order, new_quantity: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotSupplier);
        order.quantity = new_quantity;
    }

    // Update deadline
    public entry fun update_order_deadline(order: &mut Order, new_deadline: u64, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotSupplier);
        order.deadline = new_deadline;
    }

    // Update order status
    public entry fun update_order_status(order: &mut Order, completed: vector<u8>, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), ENotSupplier);
        order.status = completed;
    }

    // Add more cash to escrow
    public entry fun add_funds_to_order(order: &mut Order, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == order.buyer, ENotSupplier);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut order.escrow, added_balance);
    }

    // Withdraw funds from escrow
    public entry fun request_refund(order: &mut Order, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == order.buyer, ENotSupplier);
        assert!(!order.orderFulfilled && !order.dispute, EInvalidWithdrawal); // Ensure the order is not fulfilled and there's no ongoing dispute

        let escrow_amount = balance::value(&order.escrow);
        let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, order.buyer);

        reset_order_state(order);
    }
}
