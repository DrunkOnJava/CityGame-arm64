#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>
#include <time.h>
#include "rci_demand.h"

// Forward declarations for assembly functions
extern int _rci_init(void);
extern void _rci_tick(const DemandFactors* factors);
extern const RCIDemand* _rci_get_demand(void);
extern float _rci_calculate_lot_desirability(int zone_type, float land_value, float commute_time, float services);
extern void _rci_process_lot_development(LotInfo* lot, const DemandFactors* factors);
extern void _rci_cleanup(void);

// Test data
static DemandFactors test_factors = {
    .tax_rate = 0.05f,           // 5% tax
    .unemployment_rate = 0.08f,   // 8% unemployment
    .average_commute_time = 25.0f, // 25 minutes
    .education_level = 0.7f,      // 70% education
    .pollution_level = 0.3f,      // 30% pollution
    .crime_rate = 0.02f,         // 2% crime
    .land_value = 0.8f,          // 80% land value
    .utility_coverage = 0.9f     // 90% utility coverage
};

static int test_count = 0;
static int tests_passed = 0;

#define ASSERT_FLOAT_EQ(expected, actual, tolerance) \
    do { \
        test_count++; \
        float diff = fabsf((expected) - (actual)); \
        if (diff <= (tolerance)) { \
            tests_passed++; \
            printf("✓ Test %d PASSED: %.3f ≈ %.3f (diff: %.6f)\n", test_count, expected, actual, diff); \
        } else { \
            printf("✗ Test %d FAILED: Expected %.3f, got %.3f (diff: %.6f)\n", test_count, expected, actual, diff); \
        } \
    } while(0)

#define ASSERT_RANGE(value, min, max) \
    do { \
        test_count++; \
        if ((value) >= (min) && (value) <= (max)) { \
            tests_passed++; \
            printf("✓ Test %d PASSED: %.3f in range [%.3f, %.3f]\n", test_count, value, min, max); \
        } else { \
            printf("✗ Test %d FAILED: %.3f not in range [%.3f, %.3f]\n", test_count, value, min, max); \
        } \
    } while(0)

void test_initialization(void) {
    printf("\n=== Testing RCI Initialization ===\n");
    
    int result = _rci_init();
    test_count++;
    if (result == 0) {
        tests_passed++;
        printf("✓ Test %d PASSED: Initialization returned 0\n", test_count);
    } else {
        printf("✗ Test %d FAILED: Initialization returned %d\n", test_count, result);
    }
    
    const RCIDemand* demand = _rci_get_demand();
    ASSERT_FLOAT_EQ(20.0f, demand->residential, 0.001f);
    ASSERT_FLOAT_EQ(10.0f, demand->commercial, 0.001f);
    ASSERT_FLOAT_EQ(15.0f, demand->industrial, 0.001f);
}

void test_demand_update(void) {
    printf("\n=== Testing Demand Update ===\n");
    
    _rci_tick(&test_factors);
    
    const RCIDemand* demand = _rci_get_demand();
    
    // Check that demands are within reasonable bounds
    ASSERT_RANGE(demand->residential, -100.0f, 100.0f);
    ASSERT_RANGE(demand->commercial, -100.0f, 100.0f);
    ASSERT_RANGE(demand->industrial, -100.0f, 100.0f);
    
    // Check detailed demands
    ASSERT_RANGE(demand->residential_low, -100.0f, 100.0f);
    ASSERT_RANGE(demand->residential_medium, -100.0f, 100.0f);
    ASSERT_RANGE(demand->residential_high, -100.0f, 100.0f);
    ASSERT_RANGE(demand->commercial_low, -100.0f, 100.0f);
    ASSERT_RANGE(demand->commercial_high, -100.0f, 100.0f);
    
    printf("Demand values:\n");
    printf("  Residential: %.2f (Low: %.2f, Med: %.2f, High: %.2f)\n", 
           demand->residential, demand->residential_low, 
           demand->residential_medium, demand->residential_high);
    printf("  Commercial: %.2f (Low: %.2f, High: %.2f)\n", 
           demand->commercial, demand->commercial_low, demand->commercial_high);
    printf("  Industrial: %.2f (Agri: %.2f, Dirty: %.2f, Manu: %.2f, Tech: %.2f)\n", 
           demand->industrial, demand->industrial_agriculture, 
           demand->industrial_dirty, demand->industrial_manufacturing, 
           demand->industrial_hightech);
}

void test_lot_desirability(void) {
    printf("\n=== Testing Lot Desirability ===\n");
    
    // Test different zone types
    float desirability;
    
    desirability = _rci_calculate_lot_desirability(ZONE_RESIDENTIAL_LOW, 0.8f, 25.0f, 0.9f);
    ASSERT_RANGE(desirability, 0.0f, 1.0f);
    
    desirability = _rci_calculate_lot_desirability(ZONE_COMMERCIAL_LOW, 0.6f, 30.0f, 0.8f);
    ASSERT_RANGE(desirability, 0.0f, 1.0f);
    
    desirability = _rci_calculate_lot_desirability(ZONE_INDUSTRIAL_DIRTY, 0.4f, 45.0f, 0.7f);
    ASSERT_RANGE(desirability, 0.0f, 1.0f);
    
    // Test invalid zone
    desirability = _rci_calculate_lot_desirability(ZONE_NONE, 0.5f, 30.0f, 0.8f);
    ASSERT_FLOAT_EQ(0.0f, desirability, 0.001f);
}

void test_lot_development(void) {
    printf("\n=== Testing Lot Development ===\n");
    
    LotInfo lot = {
        .zone_type = ZONE_RESIDENTIAL_LOW,
        .population = 100,
        .jobs = 0,
        .desirability = 0.5f,
        .growth_rate = 0.0f,
        .last_update_tick = 0
    };
    
    uint32_t initial_population = lot.population;
    float initial_desirability = lot.desirability;
    
    _rci_process_lot_development(&lot, &test_factors);
    
    // Check that desirability was updated
    test_count++;
    if (lot.desirability != initial_desirability) {
        tests_passed++;
        printf("✓ Test %d PASSED: Desirability updated from %.3f to %.3f\n", 
               test_count, initial_desirability, lot.desirability);
    } else {
        printf("✗ Test %d FAILED: Desirability unchanged\n", test_count);
    }
    
    // Check bounds
    ASSERT_RANGE(lot.desirability, 0.0f, 1.0f);
    ASSERT_RANGE(lot.growth_rate, -10.0f, 10.0f);  // Reasonable growth rate bounds
    
    printf("Lot after development:\n");
    printf("  Population: %u -> %u\n", initial_population, lot.population);
    printf("  Desirability: %.3f -> %.3f\n", initial_desirability, lot.desirability);
    printf("  Growth rate: %.3f\n", lot.growth_rate);
}

void test_stress_scenarios(void) {
    printf("\n=== Testing Stress Scenarios ===\n");
    
    // High tax scenario
    DemandFactors high_tax = test_factors;
    high_tax.tax_rate = 0.25f;  // 25% tax
    
    _rci_tick(&high_tax);
    const RCIDemand* demand = _rci_get_demand();
    
    test_count++;
    if (demand->residential < test_factors.tax_rate * 10.0f) {  // Should be lower than normal
        tests_passed++;
        printf("✓ Test %d PASSED: High tax reduces residential demand\n", test_count);
    } else {
        printf("✗ Test %d FAILED: High tax didn't reduce demand as expected\n", test_count);
    }
    
    // High pollution scenario
    DemandFactors high_pollution = test_factors;
    high_pollution.pollution_level = 0.9f;  // 90% pollution
    
    _rci_tick(&high_pollution);
    demand = _rci_get_demand();
    
    // Should affect residential more than industrial
    ASSERT_RANGE(demand->residential, -100.0f, 50.0f);  // Should be reduced
    
    // Low utility scenario
    DemandFactors low_utility = test_factors;
    low_utility.utility_coverage = 0.1f;  // 10% coverage
    
    _rci_tick(&low_utility);
    demand = _rci_get_demand();
    
    ASSERT_RANGE(demand->residential, -100.0f, 100.0f);  // Should be affected
}

void benchmark_performance(void) {
    printf("\n=== Performance Benchmark ===\n");
    
    const int iterations = 10000;
    
    printf("Running %d iterations of RCI update...\n", iterations);
    
    clock_t start = clock();
    
    for (int i = 0; i < iterations; i++) {
        _rci_tick(&test_factors);
    }
    
    clock_t end = clock();
    double cpu_time = ((double)(end - start)) / CLOCKS_PER_SEC;
    
    printf("Time for %d iterations: %.4f seconds\n", iterations, cpu_time);
    printf("Average time per update: %.6f seconds\n", cpu_time / iterations);
    printf("Updates per second: %.0f\n", iterations / cpu_time);
    
    // Benchmark lot desirability calculations
    start = clock();
    
    for (int i = 0; i < iterations; i++) {
        _rci_calculate_lot_desirability(ZONE_RESIDENTIAL_LOW, 0.8f, 25.0f, 0.9f);
    }
    
    end = clock();
    cpu_time = ((double)(end - start)) / CLOCKS_PER_SEC;
    
    printf("Desirability calculations per second: %.0f\n", iterations / cpu_time);
}

int main(void) {
    printf("RCI Demand System - ARM64 Assembly Test Suite\n");
    printf("Agent A4 - Simulation Team\n");
    printf("===========================================\n");
    
    test_initialization();
    test_demand_update();
    test_lot_desirability();
    test_lot_development();
    test_stress_scenarios();
    benchmark_performance();
    
    printf("\n=== Test Summary ===\n");
    printf("Tests run: %d\n", test_count);
    printf("Tests passed: %d\n", tests_passed);
    printf("Tests failed: %d\n", test_count - tests_passed);
    printf("Success rate: %.1f%%\n", (float)tests_passed / test_count * 100.0f);
    
    _rci_cleanup();
    
    return (test_count == tests_passed) ? 0 : 1;
}