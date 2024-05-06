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
    const ENotBuyer: u64 = 9; // Added error for not being the buyer

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
    public fun get_product(order: &Order): &vector<u8> {
        &order.product
    }

    public fun get_order_price(order: &Order): u64 {
        order.price
    }

    public fun get_order_status(order: &Order): &vector<u8> {
        &order.status
    }

    public fun get_order_deadline(order: &Order): u64 {
        order.deadline
    }

    public fun get_order_supplier(order: &Order): &Option<address> {
        &order.supplier
    }

    public fun get_order_rating(order: &Order): &Option<u64> {
        &order.rating
    }

    // Public - Entry functions

    // Create a new order
    public entry fun create_order(
        product: vector<u8>,
        quantity: u64,
        price: u64,
        clock: &Clock,
        duration: u64,
        open: vector<u8>,
        ctx: &mut TxContext,
    ) {
        let order_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + duration;
        transfer::share_object(Order {
            id: order_id,
            buyer: tx_context::sender(ctx),
            supplier: none(), // Set to an initial value, can be updated later
            product,
            quantity,
            rating: none(),
            status: open,
            price,
            escrow: balance::zero(),
            orderFulfilled: false,
            dispute: false,
            created_at: clock::timestamp_ms(clock),
            deadline,
        });
    }

    // Supplier accepts the order
    public entry fun accept_order(order: &mut Order, ctx: &mut TxContext) {
        assert!(!is_some(&order.supplier), EInvalidOrder);
        order.supplier = some(tx_context::sender(ctx));
    }

    // Fulfill order
    public entry fun fulfill_order(order: &mut Order, clock: &Clock, ctx: &mut TxContext) {
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

    // Resolve dispute if any between buyer and supplier
    public entry fun resolve_dispute(order: &mut Order, resolved: bool, ctx: &mut TxContext) {
        assert!(order.buyer == tx_context::sender(ctx), EDispute);
        assert!(order.dispute, EAlreadyResolved);
        assert!(is_some(&order.supplier), EInvalidOrder);
        let escrow_amount = balance::value(&order.escrow);
        let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
        if resolved {
            let supplier = *borrow(&order.supplier);
            // Transfer funds to the supplier
            transfer::public_transfer(escrow_coin, supplier);
        } else {
            // Refund funds to the buyer
            transfer::public_transfer(escrow_coin, order.buyer);
        };

        // Reset order state
        order.supplier = none();
        order.orderFulfilled = false;
        order.dispute = false;
    }

    // Release payment to the supplier after order is fulfilled
    public entry fun release_payment(
        order: &mut Order,
        clock: &Clock,
        review: vector<u8>,
        ctx: &mut TxContext,
    ) {
        assert!(order.buyer == tx_context::sender(ctx), ENotBuyer);
        assert!(order.orderFulfilled && !order.dispute, EInvalidProduct);
        assert!(clock::timestamp_ms(clock) > order.deadline, EDeadlinePassed);
        assert!(is_some(&order.supplier), EInvalidOrder);
        let supplier = *borrow(&order.supplier);
        let escrow_amount = balance::value(&order.escrow);
        assert!(escrow_amount > 0, EInsufficientEscrow); // Ensure there are enough funds in escrow
        let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
        // Transfer funds to the supplier
        transfer::public_transfer(escrow_coin, supplier);

        // Create a new product record
        let productRecord = ProductRecord {
            id: object::new(ctx),
            buyer: tx_context::sender(ctx),
            review,
        };

        // Change accessibility of product record
        transfer::public_transfer(productRecord, tx_context::sender(ctx));

        // Reset order state
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
        assert!(
            order.buyer == tx_context::sender(ctx)
                || contains(&order.supplier, &tx_context::sender(ctx)),
            ENotSupplier
        );

        // Refund funds to the buyer if not yet paid and order is not fulfilled or disputed
        if is_some(&order.supplier) && !order.orderFulfilled && !order.dispute {
            let escrow_amount = balance::value(&order.escrow);
            let escrow_coin = coin::take(&mut order.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, order.buyer);
        };

        // Reset order state
        order.supplier = none();
        order.orderFulfilled = false;
        order.dispute = false;
        order.rating = none(); // Reset the rating as well
    }

}