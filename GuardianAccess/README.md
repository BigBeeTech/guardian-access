# GuardianAccess

An advanced whitelist management smart contract for token launches and exclusive events with multi-tier access control and allocation management.

## Overview

GuardianAccess enables projects to manage pre-approved participants through a sophisticated tier system with allocation limits, phased access, and referral tracking. Perfect for token sales, NFT drops, and exclusive events.

## Key Features

- **Multi-Tier System**: Bronze (10 STX), Silver (50 STX), Gold (100 STX) tiers
- **Phased Launch**: Tier-based early access before public release
- **Allocation Control**: Individual spending limits with real-time tracking
- **Referral Tracking**: Monitor who brings new participants and their volume
- **Purchase Analytics**: Comprehensive participation statistics
- **Admin Dashboard**: Easy management of participants and sale phases

## Usage

### For Administrators
- `initialize-tiers()` - Set up tier configurations
- `add-to-whitelist(address, tier, referrer)` - Add new participants
- `update-sale-phase(phase)` - Control sale progression
- `remove-from-whitelist(address)` - Deactivate participants

### For Participants
- `purchase-allocation(amount)` - Buy tokens/participate in sale
- `is-eligible-for-purchase(user, amount)` - Check purchase eligibility
- `get-whitelist-info(address)` - View your tier and allocation status

### Query Functions
- `get-sale-state()` - Current phase and overall statistics
- `get-user-purchase-info(user)` - Individual purchase history
- `get-referral-stats(referrer)` - Referral performance data

## Sale Phases

1. **Inactive** (0) - No purchases allowed
2. **Gold Only** (1) - Exclusive Gold tier access
3. **Silver & Gold** (2) - Silver and Gold tier access
4. **Public** (3) - Open to all users

## Tier Benefits

- **Bronze**: Standard allocation, public phase access
- **Silver**: Higher allocation + 1 day early access
- **Gold**: Maximum allocation + 2 days early access

## Use Cases

- Token pre-sales with tiered investor access
- NFT drops with collector priority
- Exclusive event ticketing
- Investment round management
- Community reward distribution

Built for projects requiring sophisticated access control with transparent allocation management.