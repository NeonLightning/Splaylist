import spotipy
from spotipy.oauth2 import SpotifyOAuth
from plyer import notification
import easygui
import json
import argparse
import os
import webbrowser

def validate_spotify_credentials(credentials):
    client_id, client_secret, redirect_uri = credentials
    # Try to authenticate with the provided credentials
    try:
        spotipy.Spotify(auth_manager=SpotifyOAuth(client_id=client_id, client_secret=client_secret, redirect_uri=redirect_uri))
        return True
    except spotipy.oauth2.SpotifyOAuthError:
        return False

def get_spotify_credentials():
    credentials = None
    cache_path = None

    try:
        with open("spotify_credentials.json", "r") as file:
            data = json.load(file)
            credentials = data["credentials"]
            cache_path = data["cache_path"]
    except (FileNotFoundError, json.JSONDecodeError):
        url = "https://developer.spotify.com/dashboard"
        webbrowser.open(url)  # Open the URL in a web browser
        msg = "Enter your Spotify API credentials:\n\n(They can be found at https://developer.spotify.com/dashboard)"
        title = "Spotify API Credentials"
        field_names = ["Client ID:", "Client Secret:", "Redirect URI:"]
        credentials = easygui.multenterbox(msg, title, field_names)

        if credentials:
            if validate_spotify_credentials(credentials):
                cache_path = ".cache"
                data = {"credentials": credentials, "cache_path": cache_path}
                with open("spotify_credentials.json", "w") as file:
                    json.dump(data, file)
            else:
                # Display an error message or handle invalid credentials here
                # For example, you can raise an exception or show a dialog box
                return None, None

    return credentials, cache_path

def setup_spotipy_client(credentials, cache_path):
    if credentials is None:
        return None  # Return None if credentials are invalid or not provided

    client_id, client_secret, redirect_uri = credentials
    scope = "playlist-read-private playlist-read-collaborative playlist-modify-private playlist-modify-public user-read-playback-state user-read-currently-playing user-library-read"
    return spotipy.Spotify(auth_manager=SpotifyOAuth(client_id=client_id, client_secret=client_secret, redirect_uri=redirect_uri, scope=scope, cache_path=cache_path))

def get_current_track_info(spotify_client, args):
    if spotify_client:
        current_track = spotify_client.current_user_playing_track()
        if current_track and current_track['is_playing']:
            track_name = current_track['item']['name']
            artist_name = current_track['item']['artists'][0]['name']
            playlist_id = current_track['context']['uri'].split(':')[-1]
            playlist = spotify_client.playlist(playlist_id)
            playlist_name = playlist['name']
            return track_name, artist_name, playlist_id, playlist_name, args
    return None, None, None, None, args


def check_track_in_playlist(spotify_client, track_id, playlist_id):
    playlist_tracks = spotify_client.playlist_tracks(playlist_id, fields='items(track(id))')['items']
    return any(track['track']['id'] == track_id for track in playlist_tracks)


def check_track_liked(spotify_client, track_id):
    response = spotify_client.current_user_saved_tracks_contains([track_id])
    return response[0]


def add_track_to_playlist(spotify_client, track_id, playlist_id):
    spotify_client.playlist_add_items(playlist_id, [track_id])


def remove_track_from_playlist(spotify_client, track_id, playlist_id):
    spotify_client.playlist_remove_all_occurrences_of_items(playlist_id, [track_id])


def add_track_to_liked_songs(spotify_client, track_id):
    spotify_client.current_user_saved_tracks_add([track_id])


def remove_track_from_liked_songs(spotify_client, track_id):
    spotify_client.current_user_saved_tracks_delete([track_id])


def display_osd(title, message, timeout):
    notification.notify(title=title, message=message, timeout=timeout)


def parse_command_line_args():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument("-a", "--add", action="store_true", help="Add the currently playing track to the playlist")
    group.add_argument("-r", "--remove", action="store_true", help="Remove the currently playing track from the playlist")
    group.add_argument("-l", "--like", action="store_true", help="Add the currently playing track to Liked Songs")
    group.add_argument("-dl", "--dislike", action="store_true", help="Remove the currently playing track from Liked Songs")
    parser.add_argument("-t", "--timeout", type=int, default=4, help="Set the duration for OSD display in seconds")
    return parser.parse_args()


def main():
    # Install required packages if not already installed
    try:
        import spotipy
        import easygui
        import plyer
    except ImportError:
        import subprocess
        subprocess.check_call(["pip", "install", "spotipy", "easygui", "plyer"])
        import spotipy
        import easygui
        import plyer
        
        
    # Get Spotify API credentials and cache path
    credentials, cache_path = get_spotify_credentials()

    # Check if Spotify API credentials are valid
    if credentials is None:
        display_osd("Splaylist", "No valid Spotify API credentials provided.", 4)  # Use default timeout
        return
    sp = setup_spotipy_client(credentials, cache_path)

    # Check if Spotipy client is valid
    if sp is None:
        display_osd("Splaylist", "Invalid Spotipy client.", 4)  # Use default timeout
        return

    # Get command-line arguments
    args = parse_command_line_args()
    
    # Get and display the currently playing track
    track_name, artist_name, playlist_id, playlist_name, args = get_current_track_info(sp, args)
    if track_name and artist_name:
        osd_title = f"{track_name}\n{artist_name}"
        if playlist_id and playlist_name:
            osd_message = f"{osd_title}\nPlaylist: {playlist_name}"
            # Check if track is in the playlist
            track_id = sp.current_user_playing_track()['item']['id']
            if check_track_in_playlist(sp, track_id, playlist_id):
                osd_message += "\nTrack is in the playlist."
            else:
                osd_message += "\nTrack is not in the playlist."
            # Check if track is liked
            if check_track_liked(sp, track_id):
                osd_message += "\nTrack is in Liked Songs playlist."
            else:
                osd_message += "\nTrack is not in Liked Songs playlist."
            # Perform desired actions based on command-line arguments
            if args.add:
                # Check if track is already in the playlist
                if check_track_in_playlist(sp, track_id, playlist_id):
                    osd_message = f"{track_name}\n{artist_name}\n\nTrack is already in the playlist:\n{playlist_name}"
                else:
                    add_track_to_playlist(sp, track_id, playlist_id)
                    osd_message = f"{track_name}\n{artist_name}\n\nAdded to:\n{playlist_name}"
            elif args.remove:
                # Check if track is in the playlist
                if check_track_in_playlist(sp, track_id, playlist_id):
                    remove_track_from_playlist(sp, track_id, playlist_id)
                    osd_message = f"{track_name}\n{artist_name}\n\nRemoved from:\n{playlist_name}"
                else:
                    osd_message = f"Track is not in the playlist:\n\n{osd_title}\n{playlist_name}"
            elif args.like:
                # Check if track is already liked
                if check_track_liked(sp, track_id):
                    osd_message = f"{track_name}\n{artist_name}\n\nTrack is already in Liked Songs playlist."
                else:
                    add_track_to_liked_songs(sp, track_id)
                    osd_message = f"{track_name}\n{artist_name}\n\nAdded to Liked Songs playlist."
            elif args.dislike:
                # Check if track is liked
                if check_track_liked(sp, track_id):
                    remove_track_from_liked_songs(sp, track_id)
                    osd_message = f"{track_name}\n{artist_name}\n\nRemoved from Liked Songs playlist."
                else:
                    osd_message = f"Track is not in Liked Songs playlist:\n\n{osd_title}"
        else:
            osd_message = "No Playlist"
        display_osd("", osd_message, args.timeout)
    else:
        display_osd("Splaylist", "No track is currently playing.", args.timeout)


if __name__ == "__main__":
    main()
