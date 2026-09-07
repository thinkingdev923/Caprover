import axios from 'axios'
import CaptainConstants from '../src/utils/CaptainConstants'
import { getText } from '../src/utils/HttpUtils'
import VersionManager from '../src/user/system/VersionManager'

jest.mock('axios')
jest.mock('../src/docker/DockerApi', () => ({
    __esModule: true,
    default: {
        get: jest.fn(() => ({})),
    },
}))
jest.mock('../src/utils/HttpUtils', () => ({
    getText: jest.fn(),
}))
jest.mock('../src/utils/Logger', () => ({
    __esModule: true,
    default: {
        e: jest.fn(),
    },
}))

const mockedAxios = axios as jest.Mocked<typeof axios>
const mockedGetText = getText as jest.MockedFunction<typeof getText>

describe('VersionManager', () => {
    const originalImageName = CaptainConstants.configs.publishedNameOnDockerHub
    const originalVersion = CaptainConstants.configs.version
    const originalDebug = CaptainConstants.isDebug

    beforeEach(() => {
        jest.clearAllMocks()
        CaptainConstants.configs.publishedNameOnDockerHub = originalImageName
        CaptainConstants.configs.version = originalVersion
        CaptainConstants.isDebug = originalDebug
    })

    afterAll(() => {
        CaptainConstants.configs.publishedNameOnDockerHub = originalImageName
        CaptainConstants.configs.version = originalVersion
        CaptainConstants.isDebug = originalDebug
    })

    test('uses the official version API for standard CapRover installations', async () => {
        CaptainConstants.configs.publishedNameOnDockerHub = 'caprover/caprover'
        CaptainConstants.configs.version = '1.15.0'
        mockedAxios.get.mockResolvedValue({
            data: {
                status: 100,
                data: {
                    currentVersion: '1.15.0',
                    latestVersion: '1.15.4',
                    changeLogMessage: 'Release notes',
                    canUpdate: true,
                },
            },
        })

        await expect(
            new VersionManager().getCaptainImageTags()
        ).resolves.toEqual({
            currentVersion: '1.15.0',
            latestVersion: '1.15.4',
            changeLogMessage: 'Release notes',
            canUpdate: true,
        })

        expect(mockedAxios.get).toHaveBeenCalledWith(
            'https://api-v1.caprover.com/v2/versionInfo',
            { params: { currentVersion: '1.15.0' } }
        )
        expect(mockedGetText).not.toHaveBeenCalled()
    })

    test('fails safely when the official version API is unavailable', async () => {
        CaptainConstants.configs.publishedNameOnDockerHub = 'caprover/caprover'
        CaptainConstants.configs.version = '1.15.0'
        mockedAxios.get.mockRejectedValue(new Error('network failure'))

        await expect(
            new VersionManager().getCaptainImageTags()
        ).resolves.toEqual({
            currentVersion: '1.15.0',
            latestVersion: '1.15.0',
            changeLogMessage: '',
            canUpdate: false,
        })
    })

    test('reads custom image versions from Docker Hub and selects the highest tag', async () => {
        CaptainConstants.configs.publishedNameOnDockerHub = 'example/caprover'
        CaptainConstants.configs.version = '1.2.3'
        CaptainConstants.isDebug = false
        mockedGetText.mockResolvedValue(
            JSON.stringify({
                results: [
                    { name: '1.3.0' },
                    { name: 'invalid' },
                    { name: '2.0.0' },
                    { name: '1.9.0' },
                ],
            })
        )

        await expect(
            new VersionManager().getCaptainImageTags()
        ).resolves.toEqual({
            currentVersion: '1.2.3',
            latestVersion: '2.0.0',
            changeLogMessage: '',
            canUpdate: true,
        })
    })

    test('rejects an invalid Docker Hub response', async () => {
        CaptainConstants.configs.publishedNameOnDockerHub = 'example/caprover'
        CaptainConstants.isDebug = false
        mockedGetText.mockResolvedValue('invalid JSON')

        await expect(
            new VersionManager().getCaptainImageTags()
        ).rejects.toThrow('Received invalid JSON')
    })

    test('does not call Docker Hub in debug mode', async () => {
        CaptainConstants.configs.publishedNameOnDockerHub = 'captain-debug'
        CaptainConstants.configs.version = '0.0.0'
        CaptainConstants.isDebug = true

        await expect(
            new VersionManager().getCaptainImageTags()
        ).resolves.toEqual({
            currentVersion: '0.0.0',
            latestVersion: '0.0.0',
            changeLogMessage: '',
            canUpdate: false,
        })
        expect(mockedGetText).not.toHaveBeenCalled()
    })
})
