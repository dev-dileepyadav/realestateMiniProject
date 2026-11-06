@IsTest
public class REPM_GeocodeHttpMock implements HttpCalloutMock {
    private final Integer statusCode;
    private final String body;

    public REPM_GeocodeHttpMock() {
        this(200, '[{"lat":"12.9716","lon":"77.5946"}]');
    }

    public REPM_GeocodeHttpMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(body);
        return response;
    }
}
