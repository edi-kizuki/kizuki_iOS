import KizukiOnboardingFeature
import Testing

struct OnboardingCopyTests {
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
