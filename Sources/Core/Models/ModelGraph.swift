import Foundation

/// The complete model graph output
struct ModelGraph: Codable {
    /// ISO 8601 timestamp when the graph was generated
    let generatedAt: String
    
    /// Root models (those annotated with @RootModel)
    let roots: [ModelNode]
}

// MARK: - Pretty Print Extension

extension ModelGraph {
    /// Generate a human-readable tree representation
    func prettyPrint() -> String {
        var output = "Model Graph (generated: \(generatedAt))\n"
        output += String(repeating: "=", count: 50) + "\n\n"
        
        for root in roots {
            output += root.prettyPrint(indent: 0)
            output += "\n"
        }
        
        return output
    }
}

// MARK: - Graph Statistics

extension ModelGraph {
    /// Calculate statistics about the graph
    var statistics: GraphStatistics {
        var totalNodes = 0
        var totalProperties = 0
        var cyclicReferences = 0
        var maxDepth = 0
        var typeOccurrences: [String: Int] = [:]
        
        func traverse(node: ModelNode, depth: Int) {
            totalNodes += 1
            totalProperties += node.properties.count
            maxDepth = max(maxDepth, depth)
            typeOccurrences[node.name, default: 0] += 1
            
            if node.isCyclic {
                cyclicReferences += 1
            } else {
                for child in node.children {
                    traverse(node: child, depth: depth + 1)
                }
            }
        }
        
        for root in roots {
            traverse(node: root, depth: 0)
        }
        
        return GraphStatistics(
            rootCount: roots.count,
            totalNodes: totalNodes,
            totalProperties: totalProperties,
            cyclicReferences: cyclicReferences,
            maxDepth: maxDepth,
            typeOccurrences: typeOccurrences
        )
    }
}

struct GraphStatistics: Codable {
    let rootCount: Int
    let totalNodes: Int
    let totalProperties: Int
    let cyclicReferences: Int
    let maxDepth: Int
    let typeOccurrences: [String: Int]
}
