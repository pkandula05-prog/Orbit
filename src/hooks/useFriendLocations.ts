import { useEffect, useState } from 'react';

import type { FriendLocation, FriendLocationSource } from '../services/friendLocations';

export function useFriendLocations(source: FriendLocationSource): FriendLocation[] {
  const [friends, setFriends] = useState<FriendLocation[]>([]);

  useEffect(() => source.subscribe(setFriends), [source]);

  return friends;
}
