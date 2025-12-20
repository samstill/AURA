from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="encresa",
    version="0.0.1",
    author="Encresa Systems",
    author_email="contact@encresa.com",
    description="Cognitive Infrastructure SDK for Project AURA.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/encresa/encresa-python",
    project_urls={
        "Homepage": "https://encresa.com",
        "Bug Tracker": "https://github.com/encresa/encresa-python/issues",
    },
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: Other/Proprietary License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Operating System :: OS Independent",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    python_requires='>=3.8',
    keywords="encresa, aura, cognitive, infrastructure, sdk",
)
