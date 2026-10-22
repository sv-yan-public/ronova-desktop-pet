import Foundation
import CoreFoundation
for path in CommandLine.arguments.dropFirst() {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let values = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    for (key, value) in values {
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID(), !number.boolValue {
            fputs("FAILED: \(key) in \(path)\n", stderr)
            exit(1)
        }
    }
}
print("All reported checks passed.")
