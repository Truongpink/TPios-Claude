import UIKit

final class FloatingButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(
            red: 0.96,
            green: 0.18,
            blue: 0.06,
            alpha: 0.94
        )

        layer.cornerRadius = frame.width / 2
        clipsToBounds = false

        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.32
        layer.shadowRadius = 9
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let image = UIImage(
            systemName: "circle.grid.2x2.fill"
        )?.withConfiguration(
            UIImage.SymbolConfiguration(
                pointSize: 23,
                weight: .semibold
            )
        )

        setImage(image, for: .normal)
        tintColor = .white

        adjustsImageWhenHighlighted = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
