# Waste Finance Automation Smart Contract

A comprehensive blockchain-based system for automating waste collection payments and incentives on the Stacks blockchain using Clarity smart contracts.

## Overview

This smart contract facilitates a decentralized waste management ecosystem where waste generators can schedule collections, waste collectors can accept and complete jobs, and payments are automatically processed upon verification. The system includes reputation tracking, bonus incentives, and multi-stakeholder verification.

## Features

- **Multi-stakeholder ecosystem**: Waste generators, collectors, and verifiers
- **Automated payment processing**: Smart contract-based payment automation
- **Multiple waste type support**: Organic, recyclable, hazardous, and general waste
- **Reputation system**: Track performance for all participants
- **Bonus incentive structure**: Performance-based rewards for collectors
- **Verification system**: Quality control through authorized verifiers
- **Deposit-based security**: Pre-funded collections ensure payment availability

## Waste Types and Pricing

| Waste Type | Price per KG | Bonus Multiplier |
|------------|--------------|------------------|
| Organic | 50 units | 120% |
| Recyclable | 75 units | 150% |
| Hazardous | 200 units | 200% |
| General | 25 units | 100% |

## Contract Architecture

### Core Data Structures

- **Waste Generators**: Entities that produce waste and schedule collections
- **Waste Collectors**: Licensed entities that collect and transport waste
- **Waste Collections**: Individual collection jobs with full lifecycle tracking
- **Collection Verifiers**: Authorized entities that verify completed collections
- **Pricing System**: Dynamic pricing based on waste type and bonuses

### Collection Status Flow

1. **Scheduled**: Collection request created by generator
2. **In Progress**: Accepted by collector
3. **Completed**: Marked complete by collector
4. **Verified**: Verified and payment processed

## Getting Started

### Prerequisites

- Stacks blockchain environment
- STX tokens for transactions and deposits
- Clarity development tools

### Deployment

1. Deploy the contract to the Stacks blockchain
2. Initialize with default waste type pricing (automatically done)
3. Add authorized verifiers using admin functions

## Usage Guide

### For Waste Generators

#### 1. Register as Generator
```clarity
(contract-call? .waste-finance register-waste-generator "Company Name" "Location Address")
```

#### 2. Deposit Funds
```clarity
(contract-call? .waste-finance deposit-funds u1000)
```

#### 3. Schedule Collection
```clarity
(contract-call? .waste-finance schedule-waste-collection 
  u1    ; waste-type (organic)
  u50   ; weight in kg
  "Collection Location"
  u1000 ; scheduled block height
)
```

#### 4. Cancel Collection (if needed)
```clarity
(contract-call? .waste-finance cancel-waste-collection u1)
```

### For Waste Collectors

#### 1. Register as Collector
```clarity
(contract-call? .waste-finance register-waste-collector 
  "Collector Name" 
  "LICENSE123" 
  "Service Area"
)
```

#### 2. Accept Collection Job
```clarity
(contract-call? .waste-finance accept-waste-collection u1)
```

#### 3. Complete Collection
```clarity
(contract-call? .waste-finance complete-waste-collection u1)
```

#### 4. Withdraw Earnings
```clarity
(contract-call? .waste-finance withdraw-funds u500)
```

### For Verifiers

#### Verify and Process Payment
```clarity
(contract-call? .waste-finance verify-and-pay-collection u1)
```

## API Reference

### Read-Only Functions

#### `get-contract-info`
Returns overall contract statistics including total collections and rewards paid.

#### `get-waste-generator (generator-id principal)`
Retrieves generator information including reputation and statistics.

#### `get-waste-collector (collector-id principal)`
Retrieves collector information including license and earnings.

#### `get-waste-collection (collection-id uint)`
Returns detailed information about a specific collection.

#### `get-collector-balance (collector-id principal)`
Returns current balance available for withdrawal.

#### `calculate-collection-payment (waste-type uint) (weight uint)`
Calculates payment amount for a collection based on type and weight.

#### `is-collection-expired (collection-id uint)`
Checks if a scheduled collection has expired (24 hours).

### Public Functions

#### Registration Functions
- `register-waste-generator`
- `register-waste-collector`

#### Collection Management
- `schedule-waste-collection`
- `accept-waste-collection`
- `complete-waste-collection`
- `cancel-waste-collection`

#### Financial Functions
- `deposit-funds`
- `withdraw-funds`
- `verify-and-pay-collection`

#### Admin Functions
- `add-collection-verifier`
- `update-waste-type-pricing`
- `toggle-contract-status`
- `emergency-withdrawal`

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u401 | ERR_UNAUTHORIZED | Insufficient permissions |
| u404 | ERR_NOT_FOUND | Resource not found |
| u409 | ERR_ALREADY_EXISTS | Resource already exists |
| u400 | ERR_INVALID_AMOUNT | Invalid amount or parameter |
| u402 | ERR_INSUFFICIENT_BALANCE | Insufficient funds |
| u403 | ERR_INVALID_STATUS | Invalid status for operation |
| u405 | ERR_EXPIRED_COLLECTION | Collection has expired |
| u406 | ERR_INVALID_WASTE_TYPE | Invalid waste type specified |

## Security Features

- **Access Control**: Role-based permissions for all operations
- **Deposit Security**: Pre-funded collections ensure payment availability
- **Expiration Handling**: Collections expire after 24 hours if not accepted
- **Verification Requirements**: All payments require authorized verification
- **Emergency Controls**: Admin can pause contract and perform emergency withdrawals

## Economic Model

### Payment Structure
- Base payment calculated as: `waste_type_price * weight`
- Bonus payment calculated as: `(base_payment * bonus_multiplier) / 100`
- Total payment: `base_payment + bonus_payment`

### Reputation System
- All participants start with reputation score of 100
- Reputation affects future opportunities and pricing
- Tracked across all completed transactions

## Development and Testing

### Local Development
1. Set up Clarinet development environment
2. Use provided test cases for function validation
3. Deploy to testnet before mainnet

### Testing Scenarios
- Generator registration and deposit flows
- Collection scheduling and acceptance
- Payment processing and verification
- Error condition handling
- Admin function testing

## Contributing

1. Fork the repository
2. Create feature branch
3. Implement changes with tests
4. Submit pull request with detailed description