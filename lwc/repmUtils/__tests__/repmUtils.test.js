import { reduceError } from 'c/repmUtils';

describe('repmUtils', () => {
    it('reads the message from an Apex error', () => {
        expect(reduceError({ body: { message: 'Rent must be greater than zero.' } })).toBe('Rent must be greater than zero.');
        expect(reduceError({ body: [{ message: 'One' }, { message: 'Two' }] })).toBe('One, Two');
        expect(reduceError(null)).toBe('Unexpected error');
    });
});
