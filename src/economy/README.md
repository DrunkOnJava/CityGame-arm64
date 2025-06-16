# SimCity ARM64 - Economic and Population Systems

## Overview

The economic and population systems form the financial backbone of the SimCity simulation, handling taxation, budgeting, population dynamics, and economic indicators that drive city growth and development.

## System Components

### 1. Economic Constants (`economic_constants.s`)
- **Tax Rates**: Configurable tax rates for residential (5-20%), commercial (5-20%), and industrial zones (5-20%)
- **Building Values**: Property values for different building types ranging from $10,000 (low-density residential) to $100,000 (shopping malls)
- **Population Factors**: Population density per building type and job creation ratios
- **Economic Multipliers**: Factors affecting happiness, unemployment, and growth rates
- **Budget Categories**: Service costs for police, fire, health, education, transport, and utilities

### 2. Core Economic System (`economic_system.s`)
- **Economic State Structure** (256 bytes): Tracks city funds, income, expenses, tax rates, population, and RCI demand
- **Tax Collection**: Monthly tax revenue calculation based on building values and tax rates
- **RCI Demand System**: Dynamic supply and demand for Residential, Commercial, and Industrial zones
- **Economic Indicators**: Real-time economic health metrics (-100 to +100 scale)
- **Monthly Budget Processing**: Automated expense deduction and revenue collection

### 3. Population Dynamics (`population_dynamics.s`)
- **Demographics Tracking**: Age distribution (children, adults, seniors) with realistic aging progression
- **Migration System**: Population movement based on happiness and economic conditions
- **Employment Calculation**: Dynamic job matching and unemployment rate tracking
- **Education Impact**: Skill levels affecting economic productivity
- **Natural Growth**: Birth and death rates influencing population changes

### 4. Tax and Budget System (`tax_budget_system.s`)
- **Tax Efficiency**: Collection rates decrease with higher tax rates due to evasion
- **Service Cost Calculation**: Dynamic costs based on population and city size
- **Credit Rating System**: Financial health assessment (0-100 scale)
- **Deficit Management**: Debt handling and emergency fund management
- **Budget Allocation**: Distributes funds across six service categories

## Key Features

### Economic Balance
- **RCI Balance**: Optimal city composition of 40% residential, 30% commercial, 30% industrial
- **Supply & Demand**: Dynamic demand curves that respond to city development patterns
- **Land Values**: Property values influenced by nearby amenities and industrial pollution

### Tax System
- **Variable Rates**: Players can adjust tax rates with immediate economic consequences
- **Efficiency Curves**: Higher tax rates reduce collection efficiency due to evasion
- **Zone-Specific**: Different tax rates for residential, commercial, and industrial zones

### Population Mechanics
- **Realistic Demographics**: Age-based population distribution with natural progression
- **Employment Matching**: Automatic job assignment based on available positions
- **Migration Flows**: Citizens move in/out based on happiness and opportunities
- **Happiness Factors**: Employment, taxes, and services affect citizen satisfaction

### Budget Management
- **Service Costs**: Realistic maintenance expenses that scale with city size
- **Emergency Funds**: Reserve funds for handling economic crises
- **Credit Rating**: Financial credibility affects borrowing capacity
- **Deficit Spending**: Cities can operate at a deficit with consequences

## Economic Indicators

### Primary Metrics
- **City Funds**: Current treasury balance
- **Monthly Income/Expenses**: Cash flow analysis
- **Unemployment Rate**: Percentage of workforce without jobs
- **Economic Indicator**: Overall economic health (-100 to +100)
- **Land Value**: Average property values across the city

### RCI Demand Indicators
- **Residential Demand**: Need for housing based on job availability
- **Commercial Demand**: Need for businesses based on population
- **Industrial Demand**: Need for industry based on commercial requirements

## Integration with Game Systems

### UI Integration
The economic data is displayed in the interactive city view through an expanded statistics panel showing:
- Population breakdown (employed/unemployed)
- Financial status (funds, income, expenses)
- RCI demand levels
- Economic health indicators
- Land values and tax rates

### Simulation Loop
Economic updates occur every 30 simulation ticks:
1. Tax collection from all buildings
2. RCI demand recalculation
3. Population growth/migration processing
4. Service cost deduction
5. Economic indicator updates

## Performance Considerations

### Memory Efficiency
- Structures aligned to cache line boundaries (64 bytes)
- SIMD-optimized calculations where applicable
- Minimal memory footprint per economic entity

### Computational Optimization
- Lookup tables for tax efficiency calculations
- Batch processing of similar building types
- Monthly rather than per-tick calculations for performance

## Future Enhancements

### Planned Features
- **Economic Policies**: City ordinances affecting economic behavior
- **Trade System**: Import/export mechanics with neighboring cities
- **Disaster Economics**: Economic impact of natural disasters
- **Advanced Demographics**: Income stratification and social mobility
- **Regional Economy**: Multi-city economic interactions

### Expansion Opportunities
- **Stock Market**: City investment opportunities
- **Banking System**: Loans, bonds, and financial instruments
- **Economic Cycles**: Boom/bust cycles and recession mechanics
- **International Trade**: Global economic factors

## Usage Example

```assembly
// Initialize economic system
bl      init_economic_system

// Set custom tax rates (residential: 8%, commercial: 12%, industrial: 7%)
mov     w0, #8
mov     w1, #12
mov     w2, #7
bl      set_tax_rates

// Update economic system each simulation tick
mov     x0, current_tick
bl      update_economic_system

// Get current economic state
bl      get_economic_state
// x0 now points to economic_state structure
```

## Technical Specifications

- **Language**: ARM64 Assembly
- **Memory Usage**: ~1KB for core economic data
- **Update Frequency**: Every 30 simulation ticks (configurable)
- **Performance**: < 1ms per economic update on modern ARM64 processors
- **Scalability**: Supports cities up to 4096x4096 tiles

The economic system provides a realistic and engaging financial simulation that responds dynamically to player decisions and city development patterns, creating emergent gameplay through economic cause-and-effect relationships.