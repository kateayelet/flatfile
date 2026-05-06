import Foundation

struct CSVTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let headers: [String]
    let exampleRows: [[String]]

    static let builtIn: [CSVTemplate] = [
        CSVTemplate(
            name: "Blank",
            icon: "tablecells",
            headers: ["column_1", "column_2", "column_3"],
            exampleRows: []
        ),
        CSVTemplate(
            name: "Contact List",
            icon: "person.2",
            headers: ["name", "email", "phone", "company", "notes"],
            exampleRows: [
                ["Jane Doe", "jane@example.com", "555-0100", "Acme Inc", "Met at conference"],
                ["John Smith", "john@example.com", "555-0200", "Globex", "Follow up next week"]
            ]
        ),
        CSVTemplate(
            name: "Budget Tracker",
            icon: "dollarsign.circle",
            headers: ["date", "category", "description", "amount", "type"],
            exampleRows: [
                ["2026-01-15", "Food", "Groceries", "85.50", "expense"],
                ["2026-01-16", "Transport", "Bus pass", "45.00", "expense"],
                ["2026-01-31", "Income", "Freelance", "1200.00", "income"]
            ]
        ),
        CSVTemplate(
            name: "Research Log",
            icon: "doc.text.magnifyingglass",
            headers: ["date", "source", "title", "key_finding", "tags", "url", "confidence"],
            exampleRows: [
                ["2026-01-10", "PubMed", "Fiber analysis methods", "SEM confirms morphology", "fiber,SEM", "https://example.com/1", "high"],
                ["2026-01-12", "Lab notes", "Sample batch 4", "Fluorescence under 395nm UV", "UV,fluorescence", "", "medium"]
            ]
        ),
        CSVTemplate(
            name: "Task List",
            icon: "checklist",
            headers: ["task", "priority", "status", "due_date", "assignee", "notes"],
            exampleRows: [
                ["Write draft", "high", "in_progress", "2026-02-01", "Kate", "Section 3 needs data"],
                ["Review figures", "medium", "todo", "2026-02-05", "", "Check resolution"]
            ]
        ),
        CSVTemplate(
            name: "Inventory",
            icon: "shippingbox",
            headers: ["item", "sku", "quantity", "unit_price", "location", "reorder_at"],
            exampleRows: [
                ["Microscope slides", "SLD-001", "500", "0.12", "Lab A", "100"],
                ["Coverslips", "CVR-001", "200", "0.08", "Lab A", "50"],
                ["Ethanol 70%", "ETH-070", "12", "8.50", "Storage B", "4"]
            ]
        )
    ]
}
