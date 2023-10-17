import Foundation

public struct Config: Decodable {
    public var partnerId: String
    public var authToken: String
    public var prodUrl: String
    public var testUrl: String
    public var prodLambdaUrl: String
    public var testLambdaUrl: String

    public init(
        partnerId: String,
        authToken: String,
        prodUrl: String,
        testUrl: String,
        prodLambdaUrl: String,
        testLambdaUrl: String
    ) {
        self.partnerId = partnerId
        self.authToken = authToken
        self.prodUrl = prodUrl
        self.testUrl = testUrl
        self.prodLambdaUrl = prodLambdaUrl
        self.testLambdaUrl = testLambdaUrl
    }
}

public extension Config {
    init(url: URL) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = try Data(contentsOf: url)
        let decodedConfig = try decoder.decode(Config.self, from: data)
        partnerId = decodedConfig.partnerId
        authToken = decodedConfig.authToken
        prodUrl = decodedConfig.prodUrl
        testUrl = decodedConfig.testUrl
        prodLambdaUrl = decodedConfig.prodLambdaUrl
        testLambdaUrl = decodedConfig.testLambdaUrl
    }
}
