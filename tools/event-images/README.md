# Event images

The website photos are Craig's own job photos, processed — nothing is AI-generated.

    cd tools/event-images
    swiftc -O -o process process.swift
    ./process scenes/<scene>.json            # add --debug to outline the regions

Each scene JSON lists the source photo, screens to replace (corners as fractions of the photo,
plus a rendered image from screens/), small areas to soften, and the control-surface areas where
lit buttons keep their colour. Screen content is real HTML in screens/ (multiview, PowerPoint
presenter view, slides), rendered with headless Chrome. The TIMER tile uses a real render of
Stage Timer's stage output.

Source photos live in reference/ (not committed; client content).
