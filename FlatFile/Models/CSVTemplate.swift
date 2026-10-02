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
            headers: ["Name", "Notes", "Extra"],
            exampleRows: []
        ),
        CSVTemplate(
            name: "People",
            icon: "person.2",
            headers: ["Name", "Phone", "Notes"],
            exampleRows: [
                ["Mom", "555-0142", "Call on Sundays"],
                ["Sam", "555-0199", "Has the spare key"]
            ]
        ),
        CSVTemplate(
            name: "Budget",
            icon: "dollarsign.circle",
            headers: ["What", "Amount", "Notes"],
            exampleRows: [
                ["Groceries", "86", "Saturday shop"],
                ["Electric bill", "94", "Due the 15th"],
                ["Movie night", "24", ""]
            ]
        ),
        CSVTemplate(
            name: "Stuff I own",
            icon: "house",
            headers: ["Item", "Where", "Notes"],
            exampleRows: [
                ["Living room TV", "Living room", "55\" from 2019"],
                ["Living room sofa", "Living room", "Blue, needs cleaning"]
            ]
        ),
        CSVTemplate(
            name: "To-do",
            icon: "checklist",
            headers: ["Task", "When", "Notes"],
            exampleRows: [
                ["Call the dentist", "Tuesday", "Ask about the crown"],
                ["Return library books", "Friday", "They're on the hall table"]
            ]
        ),
        CSVTemplate(
            name: "Notes",
            icon: "note.text",
            headers: ["Date", "What I found", "Notes"],
            exampleRows: [
                ["Oct 1", "Library stays open late Thursday", "Until 8"],
                ["Oct 2", "Sam has a spare HDMI cable", "Ask before movie night"]
            ]
        )
    ]
}
