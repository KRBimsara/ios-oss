import Apollo
@testable import KsApi
import XCTest

final class Project_FetchAddOnsQueryDataTests: XCTestCase {
  func testFetchAddOnsQueryData_Success() {
    let producer = Project.projectProducer(from: FetchAddsOnsQueryTemplate.valid.data)
    guard let envelope = MockGraphQLClient.shared.client.data(from: producer) else {
      XCTFail()

      return
    }

    XCTAssertEqual(envelope.name, "Peppermint Fox Press: Notebooks & Stationery")
    XCTAssertEqual(envelope.id, 1_606_532_881)
    XCTAssertEqual(envelope.slug, "peppermint-fox-press-notebooks-and-stationery")
    XCTAssertEqual(envelope.state, .live)
    XCTAssertEqual(envelope.location.name, "Launceston")

    XCTAssertTrue(envelope.hasAddOns)
    XCTAssertEqual(envelope.addOns?.count, 2)

    guard let addOn = envelope.addOns?.first else {
      XCTFail()

      return
    }

    XCTAssertEqual(addOn.backersCount, 9)
    XCTAssertEqual(addOn.convertedMinimum, 4.0)
    XCTAssertEqual(addOn.description, "Translucent Sticker Sheet")
    XCTAssertEqual(addOn.estimatedDeliveryOn, 1_622_505_600.0)
    XCTAssertEqual(addOn.graphID, "UmV3YXJkLTgxOTAzMjA=")
    XCTAssertEqual(addOn.rewardsItems.count, 1)
    XCTAssertEqual(addOn.limitPerBacker, 10)
    XCTAssertEqual(addOn.title, "Paper Sticker Sheet")
    XCTAssertEqual(addOn.shippingRules?.count, 2)

    guard let hasAnExpandedShippingRule = envelope.addOns?.first?.shippingRulesExpanded?.first else {
      XCTFail()

      return
    }

    XCTAssertEqual(hasAnExpandedShippingRule.cost, 2.0)
    XCTAssertNotNil(hasAnExpandedShippingRule.location)
  }
}
