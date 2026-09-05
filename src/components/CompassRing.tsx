import { memo } from 'react';
import Svg, { Circle, G, Text as SvgText } from 'react-native-svg';

import { color, font } from '../theme/tokens';
import { normalizeDegrees } from '../lib/geo';
import type { FriendReading } from '../lib/compassModel';

/** Everything is laid out in the artboards' 300-unit square and scaled by the viewBox. */
const VIEW = 300;
const CENTER = VIEW / 2;
const TRACK_RADIUS = 132;
const TRACK_CIRCUMFERENCE = 2 * Math.PI * TRACK_RADIUS;
const MARKER_Y = 18;
const MARKER_RADIUS = 13;
const HEADING_DOT_Y = 18.9;
const HEADING_DOT_RADIUS = 13.5;

type TickRingProps = {
  stroke: string;
  count: number;
  dashLength: number;
  strokeWidth: number;
  radius: number;
};

function TickRing({ stroke, count, dashLength, strokeWidth, radius }: TickRingProps) {
  const gap = (2 * Math.PI * radius) / count - dashLength;

  return (
    <Circle
      cx={CENTER}
      cy={CENTER}
      r={radius}
      fill="none"
      stroke={stroke}
      strokeWidth={strokeWidth}
      strokeDasharray={[dashLength, gap]}
      strokeDashoffset={dashLength / 2}
      transform={`rotate(-90 ${CENTER} ${CENTER})`}
    />
  );
}

type CompassRingProps = {
  size: number;
  heading: number;
  markers: FriendReading[];
};

/**
 * North-up dial: friends sit at their true bearing, the red body shows where the phone is
 * pointing, and the blue arc is the sweep from north to that heading.
 */
function CompassRingComponent({ size, heading, markers }: CompassRingProps) {
  const swept = (normalizeDegrees(heading) / 360) * TRACK_CIRCUMFERENCE;

  return (
    <Svg width={size} height={size} viewBox={`0 0 ${VIEW} ${VIEW}`}>
      <TickRing stroke={color.neutral400} count={72} dashLength={2} strokeWidth={8} radius={148} />
      <TickRing stroke={color.neutral600} count={8} dashLength={3} strokeWidth={16} radius={144} />

      <Circle
        cx={CENTER}
        cy={CENTER}
        r={TRACK_RADIUS}
        fill="none"
        stroke={color.neutral300}
        strokeWidth={8}
      />
      <Circle
        cx={CENTER}
        cy={CENTER}
        r={TRACK_RADIUS}
        fill="none"
        stroke={color.blue}
        strokeWidth={8}
        strokeDasharray={[swept, TRACK_CIRCUMFERENCE]}
        transform={`rotate(-90 ${CENTER} ${CENTER})`}
      />

      {markers.map((marker) => (
        <G key={marker.id} transform={`rotate(${marker.bearing} ${CENTER} ${CENTER})`}>
          <Circle
            cx={CENTER}
            cy={MARKER_Y}
            r={MARKER_RADIUS}
            fill={color.bg}
            stroke={marker.onTarget ? color.onTarget : color.yellow}
            strokeWidth={3}
            opacity={marker.stale ? 0.45 : 1}
          />
          <SvgText
            x={CENTER}
            y={MARKER_Y}
            dy={3.9}
            textAnchor="middle"
            fontFamily={font.heading}
            fontSize={11}
            fontWeight="700"
            fill={marker.onTarget ? color.onTarget : color.yellow}
            opacity={marker.stale ? 0.45 : 1}
            transform={`rotate(${-marker.bearing} ${CENTER} ${MARKER_Y})`}
          >
            {marker.initial}
          </SvgText>
        </G>
      ))}

      <G transform={`rotate(${heading} ${CENTER} ${CENTER})`}>
        <Circle cx={CENTER} cy={HEADING_DOT_Y} r={HEADING_DOT_RADIUS} fill={color.red} />
      </G>
    </Svg>
  );
}

export const CompassRing = memo(CompassRingComponent);
