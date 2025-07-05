DeFiDerivatives
===============

* * * * *

Table of Contents
-----------------

-   Introduction

-   Features

-   Error Codes

-   Constants

-   Data Maps and Variables

-   Functions

    -   Private Functions

    -   Public Functions

    -   Advanced Risk Management and Liquidation System

-   Getting Started

-   Deployment

-   Usage Examples

-   Security Considerations

-   Contributing

-   License

-   Contact

* * * * *

Introduction
------------

**DeFiDerivatives** is a Clarity smart contract designed for decentralized trading of on-chain futures and options contracts. It provides a robust framework for managing collateral, executing settlements, and implementing essential risk controls within a transparent and trustless environment. I aim to bring traditional financial derivatives to the blockchain, offering users new avenues for hedging and speculation.

* * * * *

Features
--------

-   **Futures Contracts:** I allow for the creation and management of futures contracts with defined underlying assets, strike prices, and expiry blocks.

-   **Options Contracts:** I support both **CALL** and **PUT** options, including premium handling and exercise mechanisms.

-   **Collateral Management:** I securely lock collateral for futures and options positions to ensure contract integrity.

-   **Decentralized Settlement:** I facilitate on-chain settlement of contracts based on oracle prices at expiry or exercise.

-   **Risk Controls:** I implement `MIN_COLLATERAL_RATIO` and `LIQUIDATION_THRESHOLD` to mitigate counterparty risk.

-   **Liquidation Mechanism:** I allow for the liquidation of undercollateralized positions, maintaining solvency and market stability.

-   **User Balance Tracking:** I manage user balances for various assets, enabling seamless deposits and withdrawals.

* * * * *

Error Codes
-----------

I utilize a comprehensive set of error codes to indicate specific issues during execution:

-   `u100`: `ERR_UNAUTHORIZED` - The caller does not have the necessary permissions.

-   `u101`: `ERR_INVALID_AMOUNT` - An invalid or zero amount was provided.

-   `u102`: `ERR_INSUFFICIENT_COLLATERAL` - The user has insufficient collateral for the operation.

-   `u103`: `ERR_CONTRACT_NOT_FOUND` - The specified contract ID does not exist.

-   `u104`: `ERR_CONTRACT_EXPIRED` - The contract has already expired.

-   `u105`: `ERR_ALREADY_SETTLED` - The contract has already been settled or exercised.

-   `u106`: `ERR_NOT_EXPIRED` - The contract has not yet expired.

-   `u107`: `ERR_INVALID_STRIKE` - An invalid or zero strike price was provided.

* * * * *

Constants
---------

-   `CONTRACT_OWNER`: Defines the deployer of the contract, who holds administrative privileges.

-   `MIN_COLLATERAL_RATIO`: `u150` (150%) - The minimum collateral required as a percentage of the contract's value.

-   `LIQUIDATION_THRESHOLD`: `u120` (120%) - The collateral ratio below which a position becomes eligible for liquidation.

* * * * *

Data Maps and Variables
-----------------------

-   `futures-contracts`: A map storing details of all created futures contracts.

    -   `creator`: Principal of the contract creator.

    -   `counterparty`: Optional principal of the matched counterparty.

    -   `underlying-asset`: ASCII string (max 10 chars) for the asset.

    -   `contract-size`: Unit of the underlying asset.

    -   `strike-price`: Price at which the contract can be settled.

    -   `expiry-block`: Block height at which the contract expires.

    -   `collateral-amount`: Amount of collateral locked.

    -   `is-settled`: Boolean indicating if the contract is settled.

    -   `settlement-price`: Optional unit for the final settlement price.

-   `options-contracts`: A map storing details of all created options contracts.

    -   `creator`: Principal of the option seller/writer.

    -   `holder`: Optional principal of the option holder.

    -   `underlying-asset`: ASCII string (max 10 chars) for the asset.

    -   `contract-size`: Unit of the underlying asset.

    -   `strike-price`: Price at which the option can be exercised.

    -   `expiry-block`: Block height at which the option expires.

    -   `option-type`: ASCII string (max 4 chars), either `"CALL"` or `"PUT"`.

    -   `premium`: The cost paid by the holder to the creator.

    -   `collateral-amount`: Amount of collateral locked by the creator.

    -   `is-exercised`: Boolean indicating if the option has been exercised.

    -   `is-settled`: Boolean indicating if the option has been settled.

-   `user-balances`: A map tracking the balance of different assets for each user.

    -   `user`: Principal of the user.

    -   `asset`: ASCII string (max 10 chars) for the asset.

    -   `balance`: Unit representing the user's balance of that asset.

-   `collateral-deposits`: A map tracking collateral deposited for specific contracts.

    -   `user`: Principal of the user who deposited collateral.

    -   `contract-id`: Unit ID of the contract.

    -   `contract-type`: ASCII string (max 7 chars), either `"FUTURES"` or `"OPTIONS"`.

    -   `amount`: Unit representing the deposited collateral amount.

-   `next-contract-id`: A data variable storing the next available contract ID, initialized to `u1`.

-   `oracle-price`: A data variable storing the current oracle price, initialized to `u0`. **Note:** This variable requires an external oracle integration for production use.

-   `last-price-update`: A data variable storing the block height of the last oracle price update, initialized to `u0`.

* * * * *

Functions
---------

### Private Functions

-   `(get-user-balance (user principal) (asset (string-ascii 10)))`:

    -   Retrieves the balance of a specific asset for a given user. Returns `u0` if no balance is found.

-   `(update-user-balance (user principal) (asset (string-ascii 10)) (new-balance uint))`:

    -   Updates the balance of a specific asset for a given user.

-   `(calculate-collateral-requirement (contract-size uint) (strike-price uint))`:

    -   Calculates the minimum collateral required for a contract based on its size, strike price, and `MIN_COLLATERAL_RATIO`.

-   `(is-contract-expired (expiry-block uint))`:

    -   Checks if a contract has expired by comparing the current `block-height` with the `expiry-block`.

-   `(validate-collateral (user principal) (required-amount uint) (asset (string-ascii 10)))`:

    -   Verifies if a user has sufficient balance for a required collateral amount.

### Public Functions

-   `(deposit-funds (amount uint) (asset (string-ascii 10)))`:

    -   Allows any user to deposit `amount` of a specified `asset` into their contract balance.

    -   **Errors:** `ERR_INVALID_AMOUNT` if `amount` is zero.

-   `(withdraw-funds (amount uint) (asset (string-ascii 10)))`:

    -   Allows any user to withdraw `amount` of a specified `asset` from their contract balance.

    -   **Errors:** `ERR_INVALID_AMOUNT` if `amount` is zero, `ERR_INSUFFICIENT_COLLATERAL` if the user's balance is less than `amount`.

-   `(create-futures-contract (underlying-asset (string-ascii 10)) (contract-size uint) (strike-price uint) (expiry-block uint))`:

    -   Enables a user to create a new futures contract. Collateral is locked upon creation.

    -   **Errors:** `ERR_INVALID_AMOUNT` if `contract-size` is zero, `ERR_INVALID_STRIKE` if `strike-price` is zero, `ERR_CONTRACT_EXPIRED` if `expiry-block` is not in the future, `ERR_INSUFFICIENT_COLLATERAL` if the creator lacks sufficient funds.

-   `(create-options-contract (underlying-asset (string-ascii 10)) (contract-size uint) (strike-price uint) (expiry-block uint) (option-type (string-ascii 4)) (premium uint))`:

    -   Enables a user to create a new options contract (CALL or PUT). Collateral is locked by the creator, and a premium is specified.

    -   **Errors:** Similar to `create-futures-contract` with additional checks for `option-type`.

-   `(exercise-option (contract-id uint))`:

    -   Allows the holder of an option contract to exercise it if it's in-the-money and not expired. The payout is calculated and transferred, and remaining collateral is returned to the creator.

    -   **Errors:** `ERR_CONTRACT_NOT_FOUND`, `ERR_UNAUTHORIZED` if not the holder, `ERR_ALREADY_SETTLED`, `ERR_CONTRACT_EXPIRED`, `ERR_INVALID_AMOUNT` if not in-the-money.

### Advanced Risk Management and Liquidation System

-   `(liquidate-undercollateralized-position (contract-id uint) (contract-type (string-ascii 7)))`:

    -   Allows any user to liquidate an undercollateralized futures or options contract. A `liquidation-bonus` (5%) is awarded to the liquidator.

    -   **Futures Liquidation:** Checks if the `collateral-ratio` falls below `LIQUIDATION_THRESHOLD`.

    -   **Options Liquidation:** Currently, options liquidation is simpler, transferring a bonus to the liquidator if settled.

    -   **Errors:** `ERR_CONTRACT_NOT_FOUND`, `ERR_ALREADY_SETTLED`, `ERR_INSUFFICIENT_COLLATERAL` (for futures if not under threshold).

* * * * *

Getting Started
---------------

To interact with this contract, you'll need a Clarity development environment.

1.  **Clone the repository:** (Assuming this contract is part of a larger project)

    Bash

    ```
    git clone [repository-url]
    cd [repository-name]

    ```

2.  **Install Clarity tools:** If you don't have them, follow the official Stacks documentation for setting up your development environment.

3.  **Compile and deploy:** Use the Clarity CLI or a deployment tool to deploy the `DeFiDerivatives` contract to a Stacks blockchain.

* * * * *

Deployment
----------

The contract can be deployed to any Stacks 2.0 compatible blockchain. You can use the Stacks.js library or the Clarity CLI for deployment.

**Example Deployment (Clarity CLI):**

Bash

```
clarinet deploy --manifest Clarinet.toml --contract DeFiDerivatives

```

* * * * *

Usage Examples
--------------

**(Note: These examples assume the contract is deployed and you have access to a Clarity testing environment or a deployed instance.)**

1.  **Deposit Funds:**

    Code snippet

    ```
    (as-contract call-public-function 'SP123...ContractID.DeFiDerivatives' deposit-funds u1000 "STX")

    ```

2.  **Create a Futures Contract:**

    Code snippet

    ```
    (as-contract call-public-function 'SP123...ContractID.DeFiDerivatives' create-futures-contract
      "BTC" u1 u20000 u100000) ;; 1 BTC, strike $20,000, expires at block 100,000

    ```

3.  **Create a CALL Option Contract:**

    Code snippet

    ```
    (as-contract call-public-function 'SP123...ContractID.DeFiDerivatives' create-options-contract
      "ETH" u10 u2000 u105000 "CALL" u50) ;; 10 ETH, strike $2,000, expires at block 105,000, premium $50

    ```

4.  **Exercise an Option (as holder):**

    Code snippet

    ```
    (as-contract call-public-function 'SP123...ContractID.DeFiDerivatives' exercise-option u1) ;; Assuming contract-id u1

    ```

5.  **Liquidate a Futures Position:**

    Code snippet

    ```
    (as-contract call-public-function 'SP123...ContractID.DeFiDerivatives' liquidate-undercollateralized-position u2 "FUTURES") ;; Assuming contract-id u2

    ```

* * * * *

Security Considerations
-----------------------

-   **Oracle Dependency:** The contract heavily relies on the `oracle-price` variable. In a production environment, this should be updated by a robust, decentralized oracle network to prevent manipulation. The current implementation uses a simple data variable for demonstration purposes.

-   **Access Control:** The `CONTRACT_OWNER` constant provides a basic level of access control. For more complex systems, consider a multi-signature or DAO-based ownership model.

-   **Reentrancy:** Clarity's design inherently mitigates many reentrancy attacks, but careful code review is always recommended.

-   **Integer Overflow/Underflow:** All arithmetic operations should be carefully reviewed to prevent potential overflows or underflows, especially with large `uint` values.

-   **Liquidation Logic:** The `liquidate-undercollateralized-position` function for options contracts currently has a simplified logic. A more sophisticated model considering option value and risk would be necessary for a production-grade system.

* * * * *

Contributing
------------

I welcome contributions to the DeFiDerivatives project! If you have suggestions for improvements, bug reports, or would like to contribute code, please feel free to:

1.  Fork the repository.

2.  Create a new branch for your feature or bug fix.

3.  Submit a pull request with a detailed description of your changes.

* * * * *

License
-------

This project is licensed under the MIT License. See the `LICENSE` file for more details.

* * * * *

Contact
-------

For any inquiries or further information, please reach out via GitHub issues.
