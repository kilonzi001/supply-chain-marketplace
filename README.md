# Supply Chain Module
The Supply Chain module facilitates the management of orders and transactions within a supply chain system. It provides functionalities for creating orders, accepting orders, fulfilling orders, handling disputes, releasing payments, updating orders, and managing escrow balances.

## Struct Definitions

### Order
- **id**: Unique identifier for the order.
- **buyer**: Address of the buyer placing the order.
- **product**: Description of the product being ordered.
- **quantity**: Quantity of the product.
- **price**: Price per unit of the product.
- **escrow**: Balance of SUI tokens held in escrow for the order.
- **dispute**: Boolean indicating whether there is a dispute regarding the order.
- **rating**: Optional rating given by the buyer to the supplier.
- **status**: Status of the order.
- **supplier**: Optional address of the supplier fulfilling the order.
- **orderFulfilled**: Boolean indicating whether the order has been fulfilled.
- **created_at**: Timestamp of when the order was created.
- **deadline**: Deadline for fulfilling the order.

## Public - Entry Functions

### create_order
Creates a new order with the provided product description, quantity, price, and duration.

### accept_order
Allows a supplier to accept an order they are willing to fulfill.

### fulfill_order
Marks an order as fulfilled by the assigned supplier.

### mark_order_complete
Marks an order as complete, indicating successful fulfillment.

### dispute_order
Initiates a dispute regarding an order.

### resolve_dispute
Resolves a dispute regarding an order, either refunding the buyer or paying the supplier.

### release_payment
Finalizes the payment for an order fulfilled by the supplier.

### cancel_order
Cancels an order, refunding the buyer if not yet fulfilled.

### rate_supplier
Allows the buyer to rate the supplier upon order completion.

### update_product
Updates the product description for an existing order.

### update_order_price
Updates the price of an existing order.

### update_order_quantity
Updates the quantity of an existing order.

### update_order_deadline
Updates the deadline for fulfilling an existing order.

### update_order_status
Updates the status of an existing order.

### add_funds_to_order
Adds funds to the escrow balance for an existing order.

### request_refund
Requests a refund for an order that has not been fulfilled.

## Setup

### Prerequisites

1. Rust and Cargo: Install Rust and Cargo on your development machine by following the official Rust installation instructions.

2. SUI Blockchain: Set up a local instance of the SUI blockchain for development and testing purposes. Refer to the SUI documentation for installation instructions.

### Build and Deploy

1. Clone the Supply Chain module repository and navigate to the project directory on your local machine.

2. Compile the smart contract code using the Rust compiler:

   ```bash
   cargo build --release
   ```

3. Deploy the compiled smart contract to your local SUI blockchain node using the SUI CLI or other deployment tools.

4. Note the contract address and other relevant identifiers for interacting with the deployed contract.

## Usage

### Creating an Order

To create a new order, invoke the `create_order` function with the required order details, including product description, quantity, price, and duration.

### Accepting and Fulfilling Orders

Suppliers can accept and fulfill orders using the `accept_order` and `fulfill_order` functions, respectively.

### Managing Disputes

In case of disputes, either party can initiate dispute resolution procedures using the `dispute_order` function to seek a fair resolution.

### Completing Transactions

Upon successful order fulfillment, the payment can be finalized using the `release_payment` function.

### Additional Functions

- **Updating Order Details**: Buyers can update order details such as product description, price, quantity, deadline, and status using the corresponding update functions.
- **Adding Funds to Escrow**: Buyers can add funds to the escrow balance for an order using the `add_funds_to_order` function.
- **Requesting Refunds**: Buyers can request refunds for orders that have not been fulfilled using the `request_refund` function.

## Interacting with the Smart Contract

### Using the SUI CLI

1. Use the SUI CLI to interact with the deployed smart contract, providing function arguments and transaction contexts as required.

2. Monitor transaction outputs and blockchain events to track the status of orders and transactions.

### Using Web Interfaces (Optional)

1. Develop web interfaces or applications that interact with the smart contract using JavaScript libraries such as Web3.js or Ethers.js.

2. Implement user-friendly interfaces for creating orders, managing disputes, and completing transactions on the Supply Chain platform.

## Conclusion

The Supply Chain Smart Contract offers a decentralized solution for managing orders and transactions within a supply chain system, promoting efficiency, transparency, and trust among participants. By leveraging blockchain technology, buyers and suppliers can engage in secure and transparent transactions, ultimately improving the overall supply chain management process.