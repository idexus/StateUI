/// The language a listing is written in: what its heading names, and which
/// words are drawn as its keywords.
///
/// The scanner is shared - comments, strings, annotations, capitalised names
/// and numbers read alike in all of them - and only the vocabulary differs.
/// Each vocabulary is what the listings use, plus the neighbours somebody
/// would notice missing; a word left out is drawn plain, which is a dull
/// listing rather than a wrong one.
enum CodeLanguage: CaseIterable {
    /// Every example's own code, and a host's half written in Swift.
    case swift

    /// A relay a host calls, written in Java.
    case java

    /// A relay a host calls, written in C++ behind C functions.
    case cpp

    /// Shaders for Metal.
    case metal

    /// Shaders for OpenGL and OpenGL ES.
    case glsl

    /// Shaders for Direct3D.
    case hlsl

    /// A page's own element, written in JavaScript.
    case javascript

    /// The language as a heading names it.
    var name: String {
        switch self {
        case .swift: "Swift"
        case .java: "Java"
        case .cpp: "C++"
        case .metal: "Metal"
        case .glsl: "GLSL"
        case .hlsl: "HLSL"
        case .javascript: "JavaScript"
        }
    }

    /// The words drawn as keywords.
    var keywords: Set<String> {
        switch self {
        case .swift: Self.swiftWords
        case .java: Self.javaWords
        case .cpp: Self.cppWords
        case .metal: Self.cppWords.union(Self.metalWords)
        case .glsl: Self.glslWords
        case .hlsl: Self.hlslWords
        case .javascript: Self.javascriptWords
        }
    }

    private static let swiftWords: Set<String> = [
        "as", "associatedtype", "async", "await", "break", "case", "catch",
        "class", "continue", "default", "defer", "deinit", "do", "else", "enum",
        "extension", "false", "fileprivate", "final", "for", "func", "get",
        "guard", "if", "import", "in", "indirect", "init", "inout", "internal",
        "is", "lazy", "let", "mutating", "nil", "nonisolated", "nonmutating",
        "open", "operator", "package", "private", "protocol", "public", "repeat",
        "required", "return", "self", "set", "some", "static", "struct",
        "subscript", "super", "switch", "throw", "throws", "true", "try",
        "typealias", "unowned", "var", "weak", "where", "while", "willSet",
        "didSet",
    ]

    private static let javaWords: Set<String> = [
        "abstract", "boolean", "break", "byte", "case", "catch", "char", "class",
        "continue", "default", "do", "double", "else", "enum", "extends", "false",
        "final", "finally", "float", "for", "if", "implements", "import",
        "instanceof", "int", "interface", "long", "native", "new", "null",
        "package", "private", "protected", "public", "return", "short", "static",
        "super", "switch", "synchronized", "this", "throw", "throws", "true",
        "try", "var", "void", "volatile", "while",
    ]

    private static let cppWords: Set<String> = [
        "auto", "bool", "break", "case", "catch", "char", "class", "const",
        "constexpr", "continue", "default", "delete", "do", "double", "else",
        "enum", "extern", "false", "float", "for", "if", "inline", "int",
        "namespace", "new", "nullptr", "operator", "private", "protected",
        "public", "return", "sizeof", "static", "static_cast", "struct",
        "switch", "template", "this", "throw", "true", "try", "typename",
        "uint", "unsigned", "using", "void", "while",
    ]

    private static let metalWords: Set<String> = [
        "constant", "device", "fragment", "kernel", "thread", "threadgroup",
        "vertex",
    ]

    private static let glslWords: Set<String> = [
        "bool", "break", "const", "else", "false", "float", "for", "if", "in",
        "int", "layout", "out", "precision", "highp", "mediump", "lowp",
        "return", "struct", "true", "uniform", "void", "while",
    ]

    private static let javascriptWords: Set<String> = [
        "async", "await", "break", "case", "catch", "class", "const", "continue",
        "default", "delete", "do", "else", "export", "extends", "false", "for",
        "function", "get", "if", "import", "in", "instanceof", "let", "new",
        "null", "of", "return", "set", "static", "super", "switch", "this",
        "throw", "true", "try", "typeof", "undefined", "var", "void", "while",
    ]

    private static let hlslWords: Set<String> = [
        "bool", "break", "cbuffer", "const", "else", "false", "float", "for",
        "if", "in", "int", "out", "register", "return", "static", "struct",
        "true", "uint", "void", "while",
    ]
}
