import Foundation

struct BrowseState: Equatable {
    let bucket: String
    let prefix: String

    var breadcrumbs: [Breadcrumb] {
        var crumbs: [Breadcrumb] = [Breadcrumb(name: bucket, bucket: bucket, prefix: "")]
        let parts = prefix.split(separator: "/")
        var currentPrefix = ""
        for part in parts {
            currentPrefix += "\(part)/"
            crumbs.append(Breadcrumb(name: String(part), bucket: bucket, prefix: currentPrefix))
        }
        return crumbs
    }
}

struct Breadcrumb: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let bucket: String
    let prefix: String
}
