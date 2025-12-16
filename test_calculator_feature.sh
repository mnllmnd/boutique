#!/bin/bash
# Test Script for Smart Calculator Feature

echo "🧮 SMART CALCULATOR FEATURE - BUILD TEST"
echo "=========================================="
echo ""

# Check if all required files exist
echo "✓ Checking for required files..."

FILES=(
    "mobile/lib/widgets/smart_calculator.dart"
    "mobile/lib/add_payment_page.dart"
    "mobile/lib/add_debt_page.dart"
    "mobile/lib/add_loan_page.dart"
)

MISSING=0
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        MISSING=$((MISSING + 1))
    fi
done

if [ $MISSING -eq 0 ]; then
    echo ""
    echo "✅ All required files are present"
else
    echo ""
    echo "❌ $MISSING files are missing"
    exit 1
fi

echo ""
echo "✓ Checking imports..."

# Check if SmartCalculator is properly imported
if grep -q "import 'package:boutique_mobile/widgets/smart_calculator.dart'" mobile/lib/add_payment_page.dart; then
    echo "  ✓ SmartCalculator imported in add_payment_page.dart"
else
    echo "  ✗ SmartCalculator not imported in add_payment_page.dart"
fi

if grep -q "import 'package:boutique_mobile/widgets/smart_calculator.dart'" mobile/lib/add_debt_page.dart; then
    echo "  ✓ SmartCalculator imported in add_debt_page.dart"
else
    echo "  ✗ SmartCalculator not imported in add_debt_page.dart"
fi

if grep -q "import 'package:boutique_mobile/widgets/smart_calculator.dart'" mobile/lib/add_loan_page.dart; then
    echo "  ✓ SmartCalculator imported in add_loan_page.dart"
else
    echo "  ✗ SmartCalculator not imported in add_loan_page.dart"
fi

echo ""
echo "✓ Checking for calculator methods..."

if grep -q "_openCalculator()" mobile/lib/add_payment_page.dart; then
    echo "  ✓ _openCalculator() method in add_payment_page.dart"
else
    echo "  ✗ _openCalculator() method missing from add_payment_page.dart"
fi

if grep -q "_openCalculator()" mobile/lib/add_debt_page.dart; then
    echo "  ✓ _openCalculator() method in add_debt_page.dart"
else
    echo "  ✗ _openCalculator() method missing from add_debt_page.dart"
fi

if grep -q "_openCalculator()" mobile/lib/add_loan_page.dart; then
    echo "  ✓ _openCalculator() method in add_loan_page.dart"
else
    echo "  ✗ _openCalculator() method missing from add_loan_page.dart"
fi

echo ""
echo "✓ Checking for calculator buttons..."

if grep -q "ElevatedButton.icon" mobile/lib/add_payment_page.dart && grep -q "Icons.calculate" mobile/lib/add_payment_page.dart; then
    echo "  ✓ Calculator button added to add_payment_page.dart"
else
    echo "  ✗ Calculator button missing from add_payment_page.dart"
fi

if grep -q "ElevatedButton.icon" mobile/lib/add_debt_page.dart && grep -q "Icons.calculate" mobile/lib/add_debt_page.dart; then
    echo "  ✓ Calculator button added to add_debt_page.dart"
else
    echo "  ✗ Calculator button missing from add_debt_page.dart"
fi

if grep -q "ElevatedButton.icon" mobile/lib/add_loan_page.dart && grep -q "Icons.calculate" mobile/lib/add_loan_page.dart; then
    echo "  ✓ Calculator button added to add_loan_page.dart"
else
    echo "  ✗ Calculator button missing from add_loan_page.dart"
fi

echo ""
echo "=========================================="
echo "✅ FEATURE VERIFICATION COMPLETE"
echo ""
echo "Next steps:"
echo "1. Run 'flutter clean' in the mobile directory"
echo "2. Run 'flutter pub get' to get dependencies"
echo "3. Run 'flutter run' to test the app"
echo "4. Look for the blue 'CALC' buttons in:"
echo "   - Add Payment screen"
echo "   - Add Debt screen"
echo "   - Add Loan screen"
