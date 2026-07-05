import PostgREST
import Auth
import Foundation

final class SupabaseUserProfileRepository: UserProfileRepositoryProtocol, @unchecked Sendable {

    private struct CreateUserProfileParams: Encodable, Sendable {
        let targetDisplayName: String
    }

    private struct UpdateUserProfileParams: Encodable, Sendable {
        let targetDisplayName: String
    }

    private func db() async throws -> PostgrestClient {
        let session = try await SupabaseClientProvider.auth.session
        return SupabaseClientProvider.database(accessToken: session.accessToken)
    }

    func create(displayName: String)
        async throws(UserProfileError) -> UserProfile
    {
        let params = CreateUserProfileParams(targetDisplayName: displayName)

        let dtos: [UserProfileDTO]
        do {
            dtos = try await db()
                .rpc("create_user_profile", params: params)
                .execute()
                .value
        } catch let pg as PostgrestError {
            throw UserProfileMapper.mapCreateError(pg)
        } catch {
            throw .persistenceFailure
        }

        guard let dto = dtos.first,
              let profile = UserProfileMapper.toDomain(dto)
        else {
            throw .persistenceFailure
        }
        return profile
    }

    func update(displayName: String)
        async throws(UserProfileError) -> UserProfile
    {
        let params = UpdateUserProfileParams(targetDisplayName: displayName)

        let dtos: [UserProfileDTO]
        do {
            dtos = try await db()
                .rpc("update_user_profile", params: params)
                .execute()
                .value
        } catch let pg as PostgrestError {
            throw UserProfileMapper.mapUpdateError(pg)
        } catch {
            throw .persistenceFailure
        }

        guard let dto = dtos.first,
              let profile = UserProfileMapper.toDomain(dto)
        else {
            throw .persistenceFailure
        }
        return profile
    }

    func fetch(userID: UserID)
        async throws(UserProfileError) -> UserProfile?
    {
        let dtos: [UserProfileDTO]
        do {
            dtos = try await db()
                .from("user_profiles")
                .select()
                .eq("user_id", value: userID.rawValue)
                .execute()
                .value
        } catch {
            throw .persistenceFailure
        }
        // Empty result is "no profile" not an error — RLS-filtered or
        // legacy users return [] silently per UserProfileRepositoryProtocol.
        guard let dto = dtos.first else { return nil }
        return UserProfileMapper.toDomain(dto)
    }
}
