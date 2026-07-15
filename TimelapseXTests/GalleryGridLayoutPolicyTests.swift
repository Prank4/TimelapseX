import Testing
@testable import TimelapseXGalleryLogic

struct GalleryGridLayoutPolicyTests {
    @Test func pinchOutShowsFewerLargerImages() {
        #expect(GalleryGridLayoutPolicy.columnCount(startingAt: 4, magnification: 2) == 2)
    }

    @Test func pinchInShowsMoreSmallerImages() {
        #expect(GalleryGridLayoutPolicy.columnCount(startingAt: 4, magnification: 0.5) == 8)
    }

    @Test func gridDensityStaysWithinSupportedRange() {
        #expect(GalleryGridLayoutPolicy.columnCount(startingAt: 4, magnification: 100) == 2)
        #expect(GalleryGridLayoutPolicy.columnCount(startingAt: 4, magnification: 0.01) == 8)
    }
}
