extension String {
    /// The words with their first letter in upper case, as a list of choices shows a case's name.
    var titled: String { prefix(1).uppercased() + dropFirst() }
}
