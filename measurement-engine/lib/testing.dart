/// Fixture generation for the DoseBand measurement core.
///
/// Deliberately a **separate library** from `measurement.dart`. Everything
/// here synthesises images, and nothing here may be reachable from the
/// measurement path: a renderer that can produce a badge is also a renderer
/// that could produce a convincing fake one, and keeping it out of the main
/// library means importing it is a visible decision.
///
/// Every image produced by this library belongs to [DataDomain.simulated].
library;

export 'src/testing/badge_renderer.dart';
