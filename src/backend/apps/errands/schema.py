import os
import uuid

import graphene

from core import settings
from graphene_file_upload.scalars import Upload
from graphql import GraphQLError


def store_uploaded_file(uploaded_file, user) -> str:
    """
    Handles a Django UploadedFile object (from graphene-file-upload).
    Saves it to the local MEDIA_ROOT.
    """
    # 1. Create the user-specific directory
    # Result: media/errands/1/
    relative_folder = os.path.join("errands", str(user.id))
    absolute_folder = os.path.join(settings.MEDIA_ROOT, relative_folder)

    os.makedirs(absolute_folder, exist_ok=True)

    # 2. Generate a unique filename to avoid overwriting
    # Get extension from the original file (e.g., .jpg)
    ext = os.path.splitext(uploaded_file.name)[1]
    filename = f"{uuid.uuid4().hex}{ext}"

    # 3. Define the full path where the file will be saved
    file_path = os.path.join(absolute_folder, filename)

    # 4. Save the file in chunks (memory efficient)
    try:
        with open(file_path, 'wb+') as destination:
            for chunk in uploaded_file.chunks():
                destination.write(chunk)
    except Exception as e:
        raise GraphQLError(f"Failed to save image: {str(e)}")

    # 5. Return the URL that the frontend can use to display the image
    # Result: /media/errands/1/abc-123.jpg
    url_path = os.path.join(settings.MEDIA_URL, relative_folder, filename).replace("\\", "/")
    return url_path


class UploadImage(graphene.Mutation):
    class Arguments:
        file = Upload(required=True)

    success = graphene.Boolean()
    image_url = graphene.String()
    message = graphene.String()

    def mutate(self, info, file, **kwargs):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")

        # 'file' here is a Django UploadedFile object, not Base64.
        # We need a new helper or to modify image_services.py
        try:
            url = store_uploaded_file(file, user) # New helper below
            return UploadImage(success=True, image_url=url)
        except Exception as e:
            return UploadImage(success=False, message=str(e))