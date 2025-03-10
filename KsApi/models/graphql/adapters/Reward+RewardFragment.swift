import Foundation

extension Reward {
  /**
   Creates a `Reward` from a `RewardFragment`.

    - parameter reward: The `RewardFragment` data structure.
    - parameter projectId: The associated Project's ID'.
    - parameter dateFormatter: A DateFormatter configured with the format "yyyy-MM-DD".
    - parameter expandedShippingRules: Expanded shipping rules to be included.

    - returns: A Reward.
   */

  static func reward(
    from rewardFragment: GraphAPI.RewardFragment,
    dateFormatter: DateFormatter = DateFormatter.isoDateFormatter,
    expandedShippingRules: [ShippingRule]? = nil
  ) -> Reward? {
    guard
      let rewardId = decompose(id: rewardFragment.id),
      let projectRelayId = rewardFragment.project?.id,
      let projectId = decompose(id: projectRelayId)
    else { return nil }

    let estimatedDeliveryOn = rewardFragment.estimatedDeliveryOn
      .flatMap(dateFormatter.date(from:))?.timeIntervalSince1970

    var rewardHasAddons = false

    if let addOnsAvailable = rewardFragment.allowedAddons.nodes {
      rewardHasAddons = !addOnsAvailable.isEmpty
    }

    return Reward(
      backersCount: rewardFragment.backersCount,
      convertedMinimum: rewardFragment.convertedAmount.fragments.moneyFragment.amount
        .flatMap(Double.init) ?? 0,
      description: rewardFragment.description,
      endsAt: rewardFragment.endsAt.flatMap(TimeInterval.init),
      estimatedDeliveryOn: estimatedDeliveryOn,
      hasAddOns: rewardHasAddons,
      id: rewardId,
      limit: rewardFragment.limit,
      limitPerBacker: rewardFragment.limitPerBacker,
      minimum: rewardFragment.amount.fragments.moneyFragment.amount.flatMap(Double.init) ?? 0,
      remaining: rewardFragment.remainingQuantity,
      rewardsItems: rewardItemsData(from: rewardFragment, with: projectId),
      shipping: shippingData(from: rewardFragment),
      shippingRules: shippingRulesData(from: rewardFragment),
      shippingRulesExpanded: expandedShippingRules,
      startsAt: rewardFragment.startsAt.flatMap(TimeInterval.init),
      title: rewardFragment.name
    )
  }
}

private func rewardItemsData(
  from rewardFragment: GraphAPI.RewardFragment,
  with projectId: Int
) -> [RewardsItem] {
  return rewardFragment.items?.nodes?.compactMap { item -> RewardsItem? in
    guard
      let item = item,
      let id = decompose(id: item.id),
      let rewardId = decompose(id: rewardFragment.id),
      let name = item.name
    else { return nil }

    return RewardsItem(
      id: 0, // not returned
      item: Item(
        description: nil, // not returned
        id: id,
        name: name,
        projectId: projectId
      ),
      quantity: 0, // not needed
      rewardId: rewardId
    )
  } ?? []
}

// FIXME: currently we don't get all of this information via GraphQL
private func shippingData(
  from rewardFragment: GraphAPI.RewardFragment
) -> Reward.Shipping {
  return Reward.Shipping(
    enabled: [.restricted, .unrestricted].contains(rewardFragment.shippingPreference),
    location: nil,
    preference: shippingPreference(from: rewardFragment),
    summary: nil,
    type: nil
  )
}

private func shippingPreference(from rewardFragment: GraphAPI.RewardFragment) -> Reward.Shipping.Preference {
  guard let preference = rewardFragment.shippingPreference else { return .none }

  switch preference {
  case .none: return Reward.Shipping.Preference.none
  case .restricted: return .restricted
  case .unrestricted: return .unrestricted
  default: return .none
  }
}

private func shippingRulesData(
  from rewardFragment: GraphAPI.RewardFragment
) -> [ShippingRule]? {
  return rewardFragment.shippingRules.compactMap { shippingRule -> ShippingRule? in
    guard let fragment = shippingRule?.fragments.shippingRuleFragment else { return nil }
    return ShippingRule.shippingRule(from: fragment)
  }
}
