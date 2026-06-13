with open('lib/screens/load_input_screen.dart', 'r') as f:
    content = f.read()

if '_clearDetailedForm()' in content and '_clearQuickForm()' in content:
    print("Clear forms are called.")
    print("Checking if controllers are cleared in the form methods:")
    if '_nameController.clear()' in content and '_powerValueController.clear()' in content and '_dailyHoursController.clear()' in content:
        print("Detailed form controllers are cleared.")
    if '_quickPowerController.clear()' in content and '_quickHoursController.clear()' in content:
        print("Quick form controllers are cleared.")
