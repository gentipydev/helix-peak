import '../../core/catalog/protein_target.dart';
import '../../core/router/app_router.dart';

/// The app's own URL scheme, registered in `AndroidManifest.xml` and
/// `Info.plist`.
const String geneLinkScheme = 'helixpeek';

/// The link a shared clip carries back to one protein's walk.
///
/// `helixpeek://open/gene/<slug>`: the scheme opens the app, and Flutter hands
/// the router the path, which is the walk's own ([RoutePaths.geneFor]). A
/// link to a protein the catalog no longer has lands where any other deep
/// link to one does.
Uri geneLink(ProteinTarget target) =>
    Uri(scheme: geneLinkScheme, host: 'open', path: RoutePaths.geneFor(target));
