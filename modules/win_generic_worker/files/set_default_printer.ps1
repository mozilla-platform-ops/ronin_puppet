(Get-WmiObject -Class Win32_Printer -Filter "Name='Microsoft XPS Document Writer'").SetDefaultPrinter()
