import Foundation

extension Project {
  /**
   Returns a minimal `Project` from a `ProjectFragment`
   */
  static func project(
    from projectFragment: GraphAPI.ProjectFragment,
    rewards: [Reward] = [],
    addOns: [Reward]? = nil,
    backing: Backing? = nil,
    currentUserChosenCurrency: String?
  ) -> Project? {
    guard
      let country = Country.country(from: projectFragment.country.fragments.countryFragment),
      let categoryFragment = projectFragment.category?.fragments.categoryFragment,
      let category = Project.Category.category(from: categoryFragment),
      let dates = projectDates(from: projectFragment),
      let locationFragment = projectFragment.location?.fragments.locationFragment,
      let location = Location.location(from: locationFragment),
      let memberData = projectMemberData(from: projectFragment),
      let photo = projectPhoto(from: projectFragment),
      let state = projectState(from: projectFragment.state),
      let userFragment = projectFragment.creator?.fragments.userFragment,
      let creator = User.user(from: userFragment)
    else { return nil }

    let urls = Project.UrlsEnvelope(
      web: UrlsEnvelope.WebEnvelope(project: projectFragment.url, updates: projectFragment.url + "/posts")
    )

    let availableCardTypes = projectFragment.availableCardTypes.compactMap { $0.rawValue }

    let displayPrelaunch = !projectFragment.isLaunched

    let discoverTags: [String] = projectFragment.tags
      .compactMap { tag -> String? in
        if let tagName = tag?.name {
          return tagName
        }

        return nil
      }
    /**
     NOTE: Project friends fetched by
     `fetchProjectFriends(param: Param) -> SignalProducer<[User], ErrorEnvelope>`
     */

    /**
     NOTE: `Project.generatedSlug`currently returns an internal server error for user that isn't logged in. Seeing as we need the project object even if the user isn't logged in, we can still use `Project.slug` and parse the string below to get the same result until the `Project.generatedSlug` is fixed.
     */

    let generatedSlug = projectFragment.slug
      .components(separatedBy: "/")
      .filter { $0 != "" }
      .last

    let extendedProjectProperties = extendedProject(from: projectFragment)

    return Project(
      availableCardTypes: availableCardTypes,
      blurb: projectFragment.description,
      category: category,
      country: country,
      creator: creator,
      extendedProjectProperties: extendedProjectProperties,
      memberData: memberData,
      dates: dates,
      displayPrelaunch: displayPrelaunch,
      id: projectFragment.pid,
      location: location,
      name: projectFragment.name,
      personalization: projectPersonalization(
        isStarred: projectFragment.isWatched,
        backing: backing,
        friends: []
      ),
      photo: photo,
      prelaunchActivated: projectFragment.prelaunchActivated,
      rewardData: RewardData(addOns: addOns, rewards: rewards),
      slug: generatedSlug ?? projectFragment.slug,
      staffPick: projectFragment.isProjectWeLove,
      state: state,
      stats: projectStats(from: projectFragment, currentUserChosenCurrency: currentUserChosenCurrency),
      tags: discoverTags,
      urls: urls,
      video: projectVideo(from: projectFragment)
    )
  }
}

private func projectPersonalization(isStarred: Bool,
                                    backing: Backing?,
                                    friends: [User]) -> Project.Personalization {
  return Project.Personalization(
    backing: backing,
    friends: friends,
    isBacking: backing != nil,
    isStarred: isStarred
  )
}

private func projectRewards(from rewardFragments: [GraphAPI.RewardFragment]?) -> [Reward]? {
  return rewardFragments?.compactMap { rewardFragment in
    Reward.reward(from: rewardFragment)
  }
}

/**
 Returns a minimal `Project.Dates` from a `ProjectFragment`
 */
private func projectDates(from projectFragment: GraphAPI.ProjectFragment) -> Project.Dates? {
  guard
    let deadline = projectFragment.deadlineAt.flatMap(TimeInterval.init),
    let launchedAt = projectFragment.launchedAt.flatMap(TimeInterval.init),
    let stateChangedAt = TimeInterval(projectFragment.stateChangedAt)
  else { return nil }

  let startOfToday = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970

  var featuredAtDate: TimeInterval?

  if let projectOfTheDay = projectFragment.isProjectOfTheDay {
    featuredAtDate = projectOfTheDay ? startOfToday : nil
  }

  return Project.Dates(
    deadline: deadline,
    featuredAt: featuredAtDate,
    finalCollectionDate: finalCollectionDateTimeInterval(from: projectFragment.finalCollectionDate),
    launchedAt: launchedAt,
    stateChangedAt: stateChangedAt
  )
}

private func finalCollectionDateTimeInterval(
  from string: String?,
  dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
) -> TimeInterval? {
  guard let string = string else { return nil }

  return dateFormatter.date(from: string)?.timeIntervalSince1970
}

/**
 Returns a minimal `Project.MemberData` from a `ProjectFragment`
 */
private func projectMemberData(from projectFragment: GraphAPI.ProjectFragment) -> Project.MemberData? {
  let collaboratorPermissions = Project.MemberData(permissions: projectFragment.canComment ? [.comment] : [])

  // TODO: Also used by `DashboardActionCellViewModel` and `MessagesViewModel` - but they are not using the GQL `fetchProject(param:)` call yet.
  return collaboratorPermissions
}

/**
 Returns a minimal `Project.Photo` from a `ProjectFragment`
 */
private func projectPhoto(from projectFragment: GraphAPI.ProjectFragment) -> Project.Photo? {
  guard let url = projectFragment.image?.url else { return nil }

  return Project.Photo(
    full: url,
    med: url,
    size1024x768: url,
    small: url
  )
}

private func projectState(from projectState: GraphAPI.ProjectState) -> Project.State? {
  return Project.State(rawValue: projectState.rawValue.lowercased())
}

/**
 Returns a minimal `Project.Stats` from a `ProjectFragment`
 */
private func projectStats(from projectFragment: GraphAPI.ProjectFragment,
                          currentUserChosenCurrency: String?) -> Project.Stats {
  let pledgedRawData = projectFragment.pledged.fragments.moneyFragment.amount.flatMap(Float.init)
  let pledgedRawValue = projectFragment.pledged.fragments.moneyFragment.amount.flatMap(Float.init) ?? 0
  let pledgedValue = pledgedRawData != nil ? Int(pledgedRawValue) : 0
  let fxRateValue = Float(projectFragment.fxRate)
  let convertedPledgedAmountValue = pledgedRawData != nil ? pledgedRawValue * fxRateValue : nil
  let staticUSDRateValue = Float(projectFragment.usdExchangeRate ?? 0)
  var usdExchangeRate: Float?

  if let usdExchangeRateRawValue = projectFragment.usdExchangeRate {
    usdExchangeRate = Float(usdExchangeRateRawValue)
  }

  return Project.Stats(
    backersCount: projectFragment.backersCount,
    commentsCount: projectFragment.commentsCount,
    convertedPledgedAmount: convertedPledgedAmountValue,
    currency: projectFragment.currency.rawValue,
    currentCurrency: currentUserChosenCurrency,
    currentCurrencyRate: fxRateValue,
    goal: projectFragment.goal?.fragments.moneyFragment.amount.flatMap(Float.init).flatMap(Int.init) ?? 0,
    pledged: pledgedValue,
    staticUsdRate: staticUSDRateValue,
    updatesCount: projectFragment.posts?.totalCount,
    usdExchangeRate: usdExchangeRate
  )
}

/**
 Returns a video `Project.video` from `ProjectFragment`
 */

private func projectVideo(from projectFragment: GraphAPI.ProjectFragment) -> Project.Video? {
  guard let video = projectFragment.video,
    let videoId = decompose(id: video.id),
    let high = video.videoSources?.high?.src else {
    return nil
  }

  return Project.Video(
    id: videoId,
    high: high,
    hls: video.videoSources?.hls?.src
  )
}

/**
 Returns a `ExtendedProjectProperties` object from `ProjectFragment`
 */
private func extendedProject(from projectFragment: GraphAPI.ProjectFragment) -> ExtendedProjectProperties {
  let story = projectFragment.story
  let risks = projectFragment.risks
  let environmentalCommitments = extendedProjectEnvironmentalCommitments(from: projectFragment)
  let faqs = extendedProjectFAQs(from: projectFragment)
  let minimumSingleTierPledgeAmount = projectFragment.minPledge

  let extendedProjectProperties = ExtendedProjectProperties(
    environmentalCommitments: environmentalCommitments,
    faqs: faqs,
    risks: risks,
    story: story,
    minimumPledgeAmount: minimumSingleTierPledgeAmount
  )

  return extendedProjectProperties
}

/**
 Returns a `GraphQLProject.ProjectFAQ` from `ProjectFragment`
 */

private func extendedProjectFAQs(from projectFragment: GraphAPI
  .ProjectFragment) -> [ExtendedProjectProperties.ProjectFAQ] {
  var faqs = [ExtendedProjectProperties.ProjectFAQ]()

  if let allFaqs = projectFragment.faqs?.nodes.flatMap({ $0 }) {
    for faq in allFaqs {
      guard let id = faq?.id,
        let decomposedId = decompose(id: id),
        let faqQuestion = faq?.question,
        let faqAnswer = faq?.answer else {
        continue
      }

      var createdAtDate: TimeInterval?

      if let existingDate = faq?.createdAt {
        createdAtDate = TimeInterval(existingDate)
      }

      let faq = ExtendedProjectProperties
        .ProjectFAQ(answer: faqAnswer, question: faqQuestion, id: decomposedId, createdAt: createdAtDate)

      faqs.append(faq)
    }
  }

  return faqs
}

/**
 Returns a `GraphQLProject.EnvironmentalCommitment` from `ProjectFragment`
 */

private func extendedProjectEnvironmentalCommitments(from projectFragment: GraphAPI
  .ProjectFragment) -> [ExtendedProjectProperties.EnvironmentalCommitment] {
  var environmentalCommitments = [ExtendedProjectProperties.EnvironmentalCommitment]()

  if let allEnvironmentalCommitments = projectFragment.environmentalCommitments {
    for commitment in allEnvironmentalCommitments {
      guard let id = commitment?.id,
        let decomposedId = decompose(id: id),
        let description = commitment?.description else {
        continue
      }

      var commitmentCategory: ExtendedProjectProperties.CommitmentCategory

      switch commitment?.commitmentCategory {
      case .longLastingDesign:
        commitmentCategory = .longLastingDesign
      case .sustainableMaterials:
        commitmentCategory = .sustainableMaterials
      case .environmentallyFriendlyFactories:
        commitmentCategory = .environmentallyFriendlyFactories
      case .sustainableDistribution:
        commitmentCategory = .sustainableDistribution
      case .reusabilityAndRecyclability:
        commitmentCategory = .reusabilityAndRecyclability
      default:
        commitmentCategory = .somethingElse
      }

      let environmentalCommitment = ExtendedProjectProperties
        .EnvironmentalCommitment(description: description, category: commitmentCategory, id: decomposedId)

      environmentalCommitments.append(environmentalCommitment)
    }
  }

  return environmentalCommitments
}
