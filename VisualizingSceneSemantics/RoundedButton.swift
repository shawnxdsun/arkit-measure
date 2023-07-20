/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A custom button that stands out over the camera view.
*/

import UIKit

@IBDesignable
class RoundedButton: UIButton {
    let westjetTeal: UIColor = UIColor( red: CGFloat(0/255.0), green: CGFloat(170/255.0), blue: CGFloat(165/255.0), alpha: CGFloat(1.0) )
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup() {
        backgroundColor = westjetTeal
        layer.cornerRadius = 8
        clipsToBounds = true
        setTitleColor(.white, for: [])
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    }
    
    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? tintColor : .gray
        }
    }
}
