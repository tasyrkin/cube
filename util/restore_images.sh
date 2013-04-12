#!/bin/bash

cd public/
rm -r images
tar xfv images.tar
echo `date` "- Images restored."
