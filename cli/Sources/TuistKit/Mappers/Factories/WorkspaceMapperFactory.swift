import Foundation
import TSCUtility
import TuistCore
import TuistDependencies
import TuistGenerator

protocol WorkspaceMapperFactorying {
    /// Returns the default workspace mapper.
    /// - Returns: A workspace mapping instance.
    func `default`(
        tuist: Tuist
    ) -> [WorkspaceMapping]

    /// Returns a mapper for automation commands like build and test.
    /// - Parameter config: The project configuration.
    /// - Returns: A workspace mapping instance.
    func automation(
        tuist: Tuist
    ) -> [WorkspaceMapping]
}

public final class WorkspaceMapperFactory: WorkspaceMapperFactorying {
    private let projectMapper: ProjectMapping

    public init(projectMapper: ProjectMapping) {
        self.projectMapper = projectMapper
    }

    func automation(
        tuist: Tuist
    ) -> [WorkspaceMapping] {
        var mappers: [WorkspaceMapping] = []
        mappers += self.default(
            tuist: tuist
        )

        return mappers
    }

    public func `default`(
        tuist _: Tuist
    ) -> [WorkspaceMapping] {
        var mappers: [WorkspaceMapping] = []

        mappers.append(
            ProjectWorkspaceMapper(mapper: projectMapper)
        )

        mappers.append(
            TuistWorkspaceIdentifierMapper()
        )

        mappers.append(
            TuistWorkspaceRenderMarkdownReadmeMapper()
        )

        mappers.append(
            IDETemplateMacrosMapper()
        )

        mappers.append(
            LastUpgradeVersionWorkspaceMapper()
        )

        mappers.append(ExternalDependencyPathWorkspaceMapper())

        return mappers
    }
}
