/*
	Abstract:
	Extension of Array for utility API
*/

extension Array {

    mutating func removeFirst(where predicate: (Element) throws -> Bool) rethrows {
        guard let index = try indexOf(predicate) else {
            return
        }

        removeAtIndex(index)
    }

}

/*
	Abstract:
	Extension of Date for utility API
 */

extension NSDate {
    func string(format: String) -> String {
        let formatter = NSDateFormatter()
        formatter.dateFormat = format
        return formatter.stringFromDate(self)
    }
}
