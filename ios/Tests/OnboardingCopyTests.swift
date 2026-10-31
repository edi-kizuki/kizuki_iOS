import KizukiOnboardingFeature
import Testing

struct OnboardingCopyTests {
    @Test func inspirationSkipsCollaborationQuestionsAndNoReadyStep() {
        let explore = OnboardingStep.steps(for: .explore)
        #expect(explore.count == 7)
        #expect(!explore.contains(.roles))
        #expect(!explore.contains(.availability))
        #expect(!explore.contains(.compensation))
        #expect(OnboardingStep.steps(for: .collaborate).count == 10)
        #expect(OnboardingStep.allCases.last == .location)
        #expect(EntryScreen(id: "onb-ready") == nil)
    }

    @Test func favouritesStepIsGone() {
        #expect(!OnboardingStep.allCases.map(\.id).contains("favourites"))
        #expect(EntryScreen(id: "onb-favourites") == nil)
        #expect(EntryScreen.all.count == 13)
        #expect(OnboardingStep.steps(for: .collaborate).map(\.id) == ["handle", "goal", "realm", "roles", "taste", "compensation", "availability", "city", "primer-notifications", "primer-location"])
    }
    /// Decision 51: availability is public on every profile, so onboarding must not call it private.
    @Test func availabilityCopyStatesItIsPublic() {
        let copy = OnboardingCopy.availability.lowercased()
        #expect(copy.contains("everyone sees your availability"))
        #expect(!copy.contains("availability stays private"))
        #expect(!copy.contains("availability is private"))
    }

    /// The owner-only wording stays specific to work mode and pay preference.
    @Test func ownerOnlyWordingNamesWorkModeAndPay() {
        #expect(OnboardingCopy.availability.contains("Only you see your work mode and pay preference"))
    }
}
