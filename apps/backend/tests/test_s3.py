from unittest.mock import MagicMock, patch

from services.s3 import get_presigned_url


class TestGetPresignedUrl:
    def test_returns_none_for_empty_key(self):
        assert get_presigned_url("") is None

    def test_returns_none_for_none_key(self):
        assert get_presigned_url(None) is None

    def test_returns_url_on_success(self):
        mock_client = MagicMock()
        mock_client.generate_presigned_url.return_value = "https://s3.example.com/key?sig=abc"

        with patch("services.s3._make_client", return_value=mock_client):
            result = get_presigned_url("screenshots/abc.png")

        assert result == "https://s3.example.com/key?sig=abc"
        mock_client.generate_presigned_url.assert_called_once()

    def test_returns_none_on_client_error(self):
        from botocore.exceptions import ClientError

        mock_client = MagicMock()
        mock_client.generate_presigned_url.side_effect = ClientError(
            {"Error": {"Code": "NoSuchKey", "Message": "not found"}}, "get_object"
        )

        with patch("services.s3._make_client", return_value=mock_client):
            result = get_presigned_url("screenshots/missing.png")

        assert result is None
