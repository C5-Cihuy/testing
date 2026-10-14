import Foundation

enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}
